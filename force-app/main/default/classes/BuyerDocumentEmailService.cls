public with sharing class BuyerDocumentEmailService {
    
    @InvocableMethod(label='Send Buyer Documents Email')
    public static void sendBuyerDocuments(List<Request> requests) {
        
        if (requests == null || requests.isEmpty()) {
            return;
        }
        
        for (Request req : requests) {
            
            // Negative scenario:
            // Opportunity Id or Email Template Id is missing
            if (req == null ||
                req.opportunityId == null ||
            req.emailTemplateId == null) {
                continue;
            }
            
            // Get Opportunity and Accepted Buyer Account
            List<Opportunity> opportunities = [
                SELECT Id,
                       Accepted_Buyer__c
                FROM Opportunity
                WHERE Id = :req.opportunityId
                LIMIT 1
            ];
            
            // Negative scenario:
            // Opportunity does not exist
            if (opportunities.isEmpty()) {
                continue;
            }
            
            Opportunity opp = opportunities[0];
            
            // Negative scenario:
            // Accepted Buyer is not available
            if (opp.Accepted_Buyer__c == null) {
                continue;
            }
            
            // Get a Contact with an Email from the Accepted Buyer Account
            List<Contact> contacts = [
                SELECT Id,
                       FirstName,
                       LastName,
                       Email
                FROM Contact
                WHERE AccountId = :opp.Accepted_Buyer__c
                AND Email != null
                LIMIT 1
            ];
            
            // Negative scenario:
            // No Contact or no Contact Email is available
            if (contacts.isEmpty()) {
                continue;
            }
            
            Contact buyerContact = contacts[0];
            
            // Get all Opportunity Document records
            List<Opportunity_Document__c> documents = [
                SELECT Id
                FROM Opportunity_Document__c
                WHERE Opportunity__c = :opp.Id
            ];
            
            // Negative scenario:
            // No Opportunity Documents are available
            if (documents.isEmpty()) {
                continue;
            }
            
            Set<Id> documentIds = new Set<Id>();
            
            for (Opportunity_Document__c documentRecord : documents) {
                documentIds.add(documentRecord.Id);
            }
            
            // Get Salesforce Files linked to Opportunity Documents
            List<ContentDocumentLink> fileLinks = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :documentIds
            ];
            
            // Negative scenario:
            // No files are linked to Opportunity Documents
            if (fileLinks.isEmpty()) {
                continue;
            }
            
            Set<Id> contentDocumentIds = new Set<Id>();
            
            for (ContentDocumentLink fileLink : fileLinks) {
                contentDocumentIds.add(
                    fileLink.ContentDocumentId
                    );
            }
            
            // Get the latest version of every file
            List<ContentVersion> fileVersions = [
                SELECT Title,
                       VersionData,
                       FileExtension
                FROM ContentVersion
                WHERE ContentDocumentId IN :contentDocumentIds
                AND IsLatest = true
            ];
            
            // Negative scenario:
            // No latest file version is available
            if (fileVersions.isEmpty()) {
                continue;
            }
            
            // Create email attachments
            List<Messaging.EmailFileAttachment> attachments =
                new List<Messaging.EmailFileAttachment>();
            
            for (ContentVersion fileVersion : fileVersions) {
                
                Messaging.EmailFileAttachment attachment =
                    new Messaging.EmailFileAttachment();
                
                String fileName = fileVersion.Title;
                
                if (String.isNotBlank(fileVersion.FileExtension)) {
                    fileName +=
                        '.' + fileVersion.FileExtension;
                }
                
                attachment.setFileName(fileName);
                attachment.setBody(fileVersion.VersionData);
                
                attachments.add(attachment);
            }
            
            // Create email
            Messaging.SingleEmailMessage email =
                new Messaging.SingleEmailMessage();
            
            // Use Buyer Documents Requested Email Template
            email.setTemplateId(req.emailTemplateId);
            
            // Contact is the recipient.
            // Contact First Name and Last Name merge fields
            // will use this Contact record.
            email.setTargetObjectId(buyerContact.Id);
            
            // Related Opportunity
            email.setWhatId(opp.Id);
            
            // Add all uploaded documents
            email.setFileAttachments(attachments);
            
            // Do not create an activity record
            email.setSaveAsActivity(false);
            
            // Send email
            Messaging.sendEmail(
            new Messaging.SingleEmailMessage[] {
                email
            }
            );
        }
    }
    
    
    public class Request {
        
        @InvocableVariable(
        required=true
            )
            public Id opportunityId;
        
        @InvocableVariable(
        required=true
            )
            public Id emailTemplateId;
    }
}