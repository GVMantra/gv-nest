global class EmailToCaseHandler implements Messaging.InboundEmailHandler {

    global Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

        try {
            String fromAddress = envelope.fromAddress;
            String subject = email.subject;
            String body = resolveBody(email);

            Contact matchedContact = findMatchingContact(fromAddress);

            Case newCase = new Case(
                Subject        = subject,
                Description    = body,
                SuppliedEmail  = fromAddress,
                SuppliedName   = email.fromName,
                Origin         = 'Email'
            );

            if (matchedContact != null) {
                newCase.ContactId = matchedContact.Id;
            }

            insert newCase;

            result.success = true;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'EmailToCaseHandler error: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            result.success = false;
            result.message = 'EmailToCaseHandler failed to process inbound email: ' + ex.getMessage();
        }

        return result;
    }

    private String resolveBody(Messaging.InboundEmail email) {
        if (String.isNotBlank(email.plainTextBody)) {
            return email.plainTextBody;
        }
        if (String.isNotBlank(email.htmlBody)) {
            return email.htmlBody.stripHtmlTags();
        }
        return '';
    }

    private Contact findMatchingContact(String fromAddress) {
        if (String.isBlank(fromAddress)) {
            return null;
        }

        List<Contact> matches = [SELECT Id, Email FROM Contact WHERE Email = :fromAddress LIMIT 1];

        return matches.isEmpty() ? null : matches[0];
    }
}