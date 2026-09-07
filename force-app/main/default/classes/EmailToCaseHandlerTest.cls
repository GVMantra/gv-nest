@isTest
private class EmailToCaseHandlerTest {

    private static final String MATCHED_EMAIL   = 'jane.matched@example.com';
    private static final String UNMATCHED_EMAIL = 'unknown.sender@example.com';

    @TestSetup
    static void setupData() {
        insert new Contact(
            FirstName = 'Jane',
            LastName  = 'Matched',
            Email     = MATCHED_EMAIL
        );
    }

    @isTest
    static void testMatchedSenderAssociatesContact() {
        Contact existing = [SELECT Id, Email FROM Contact WHERE Email = :MATCHED_EMAIL LIMIT 1];

        Messaging.InboundEmail email = buildInboundEmail(
            'Order status inquiry',
            'Hi, can you tell me the status of my order?',
            'Jane Matched'
        );
        Messaging.InboundEnvelope envelope = buildEnvelope(MATCHED_EMAIL);

        Test.startTest();
        Messaging.InboundEmailResult result = new EmailToCaseHandler().handleInboundEmail(email, envelope);
        Test.stopTest();

        Assert.areEqual(true, result.success, 'Handler should report success for a matched sender.');

        List<Case> cases = [SELECT Id, Subject, Description, SuppliedEmail, SuppliedName, ContactId, Origin FROM Case WHERE SuppliedEmail = :MATCHED_EMAIL];
        Assert.areEqual(1, cases.size(), 'Exactly one Case should be created for the matched sender.');

        Case createdCase = cases[0];
        Assert.areEqual('Order status inquiry', createdCase.Subject);
        Assert.areEqual('Hi, can you tell me the status of my order?', createdCase.Description);
        Assert.areEqual(MATCHED_EMAIL, createdCase.SuppliedEmail);
        Assert.areEqual(existing.Id, createdCase.ContactId, 'Case should be linked to the matching Contact.');
        Assert.areEqual('Email', createdCase.Origin);
    }

    @isTest
    static void testUnmatchedSenderCreatesCaseWithoutContact() {
        Messaging.InboundEmail email = buildInboundEmail(
            'General question',
            'I have a question about your services.',
            'Unknown Sender'
        );
        Messaging.InboundEnvelope envelope = buildEnvelope(UNMATCHED_EMAIL);

        Test.startTest();
        Messaging.InboundEmailResult result = new EmailToCaseHandler().handleInboundEmail(email, envelope);
        Test.stopTest();

        Assert.areEqual(true, result.success, 'Handler should report success for an unmatched sender.');

        List<Case> cases = [SELECT Id, Subject, Description, SuppliedEmail, ContactId, Origin FROM Case WHERE SuppliedEmail = :UNMATCHED_EMAIL];
        Assert.areEqual(1, cases.size(), 'A Case should still be created for an unmatched sender.');

        Case createdCase = cases[0];
        Assert.areEqual('General question', createdCase.Subject);
        Assert.areEqual('I have a question about your services.', createdCase.Description);
        Assert.areEqual(UNMATCHED_EMAIL, createdCase.SuppliedEmail, 'Sender email must be retained even without a Contact match.');
        Assert.areEqual(null, createdCase.ContactId, 'Case should have no Contact when the sender does not match.');
    }

    @isTest
    static void testHtmlOnlyBodyFallsBackToStrippedHtml() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'HTML only email';
        email.htmlBody = '<html><body><p>Hello <b>there</b></p></body></html>';
        email.fromName = 'HTML Sender';

        Messaging.InboundEnvelope envelope = buildEnvelope(UNMATCHED_EMAIL);

        Test.startTest();
        Messaging.InboundEmailResult result = new EmailToCaseHandler().handleInboundEmail(email, envelope);
        Test.stopTest();

        Assert.areEqual(true, result.success);

        Case createdCase = [SELECT Description FROM Case WHERE Subject = 'HTML only email' LIMIT 1];
        Assert.isTrue(createdCase.Description.contains('Hello'), 'Description should contain text extracted from the HTML body.');
        Assert.isFalse(createdCase.Description.contains('<b>'), 'Description should not contain raw HTML tags.');
    }

    @isTest
    static void testEmptyBodyFallsBackToEmptyString() {
        
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'No body at all';
        email.fromName = 'Empty Body Sender';

        Messaging.InboundEnvelope envelope = buildEnvelope(UNMATCHED_EMAIL);

        Test.startTest();
        Messaging.InboundEmailResult result = new EmailToCaseHandler().handleInboundEmail(email, envelope);
        Test.stopTest();

        Assert.areEqual(true, result.success);

        Case createdCase = [SELECT Description FROM Case WHERE Subject = 'No body at all' LIMIT 1];
        
        Assert.areEqual(null, createdCase.Description, 'Description should be blank (stored as null) when no body is supplied.');
    }

    @isTest
    static void testHandlerCatchesExceptionAndReturnsFailure() {
        
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Will fail on insert';
        email.plainTextBody = 'This should not be saved.';
        email.fromName = 'X'.repeat(300); // exceeds SuppliedName's max length

        Messaging.InboundEnvelope envelope = buildEnvelope(UNMATCHED_EMAIL);

        Test.startTest();
        Messaging.InboundEmailResult result = new EmailToCaseHandler().handleInboundEmail(email, envelope);
        Test.stopTest();

        Assert.areEqual(false, result.success, 'Handler should report failure when the Case insert throws.');
        Assert.isTrue(result.message.contains('EmailToCaseHandler failed to process inbound email'), 'Failure message should explain the cause.');

        Integer caseCount = [SELECT COUNT() FROM Case WHERE Subject = 'Will fail on insert'];
        Assert.areEqual(0, caseCount, 'No Case should be created when the insert fails.');
    }

    @isTest
    static void testBlankFromAddressSkipsContactLookup() {
        
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'No sender address';
        email.plainTextBody = 'This email has no From address on the envelope.';
        email.fromName = 'Ghost Sender';

        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        envelope.fromAddress = '';
        envelope.toAddress = 'case-intake@example.my.salesforce.com';

        Test.startTest();
        Messaging.InboundEmailResult result = new EmailToCaseHandler().handleInboundEmail(email, envelope);
        Test.stopTest();

        Assert.areEqual(true, result.success);

        Case createdCase = [SELECT ContactId, SuppliedEmail FROM Case WHERE Subject = 'No sender address' LIMIT 1];
        Assert.areEqual(null, createdCase.ContactId, 'No Contact lookup should occur when the from address is blank.');
        Assert.isTrue(String.isBlank(createdCase.SuppliedEmail), 'SuppliedEmail should be blank when the from address is blank.');
    }

    private static Messaging.InboundEmail buildInboundEmail(String subject, String plainTextBody, String fromName) {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = subject;
        email.plainTextBody = plainTextBody;
        email.fromName = fromName;
        return email;
    }

    private static Messaging.InboundEnvelope buildEnvelope(String fromAddress) {
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        envelope.fromAddress = fromAddress;
        envelope.toAddress = 'case-intake@example.my.salesforce.com';
        return envelope;
    }
}