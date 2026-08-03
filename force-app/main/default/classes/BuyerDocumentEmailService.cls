public with sharing class BuyerDocumentEmailService {
    
    @InvocableMethod(label='Send Buyer Documents Email')
    public static void sendBuyerDocuments(List<Request> requests) {
        
        if (requests == null || requests.isEmpty()) {
            return;
        }
        
        for (Request req : requests) {
            
            // Negative scenario
            if (req == null ||
                req.opportunityId == null ||
            req.emailTemplateId == null) {
                continue;
            }
            
            
            // Get Opportunity
            List<Opportunity> opportunities = [
                SELECT Id
                FROM Opportunity
                WHERE Id = :req.opportunityId
                LIMIT 1
            ];
            
            if (opportunities.isEmpty()) {
                continue;
            }
            
            Opportunity opp = opportunities[0];
            
            
            // Get Buyer Account from Interested Buyer
            List<Interested_Buyer__c> interestedBuyers = [
                SELECT Buyer_Account__c
                FROM Interested_Buyer__c
                WHERE Opportunity__c = :opp.Id
                AND Buyer_Account__c != null
                LIMIT 1
            ];
            
            // No Buyer Account found
            if (interestedBuyers.isEmpty()) {
                continue;
            }
            
            Id buyerAccountId = interestedBuyers[0].Buyer_Account__c;
            
            
            // Get Buyer Contact
            List<Contact> contacts = [
                SELECT Id,
                       FirstName,
                       LastName,
                       Email
                FROM Contact
                WHERE AccountId = :buyerAccountId
                AND Email != null
                LIMIT 1
            ];
            
            if (contacts.isEmpty()) {
                continue;
            }
            
            Contact buyerContact = contacts[0];
            
            
            // Get Opportunity Documents
            List<Opportunity_Document__c> documents = [
                SELECT Id
                FROM Opportunity_Document__c
                WHERE Opportunity__c = :opp.Id
            ];
            
            if (documents.isEmpty()) {
                continue;
            }
            
            
            Set<Id> documentIds = new Set<Id>();
            
            for (Opportunity_Document__c doc : documents) {
                documentIds.add(doc.Id);
            }
            
            
            // Get Files linked with documents
            List<ContentDocumentLink> fileLinks = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :documentIds
            ];
            
            if (fileLinks.isEmpty()) {
                continue;
            }
            
            
            Set<Id> contentDocumentIds = new Set<Id>();
            
            for (ContentDocumentLink link : fileLinks) {
                contentDocumentIds.add(link.ContentDocumentId);
            }
            
            
            // Get latest file versions
            List<ContentVersion> fileVersions = [
                SELECT Title,
                       VersionData,
                       FileExtension
                FROM ContentVersion
                WHERE ContentDocumentId IN :contentDocumentIds
                AND IsLatest = true
            ];
            
            if (fileVersions.isEmpty()) {
                continue;
            }
            
            
            // Create Attachments
            List<Messaging.EmailFileAttachment> attachments =
                new List<Messaging.EmailFileAttachment>();
            
            for (ContentVersion file : fileVersions) {
                
                Messaging.EmailFileAttachment attachment =
                    new Messaging.EmailFileAttachment();
                
                String fileName = file.Title;
                
                if (String.isNotBlank(file.FileExtension)) {
                    fileName += '.' + file.FileExtension;
                }
                
                attachment.setFileName(fileName);
                attachment.setBody(file.VersionData);
                
                attachments.add(attachment);
            }
            
            
            // Create Email
            Messaging.SingleEmailMessage email =
                new Messaging.SingleEmailMessage();
            
            email.setTemplateId(req.emailTemplateId);
            
            // Buyer Contact for merge fields
            email.setTargetObjectId(buyerContact.Id);
            
            // Opportunity merge fields
            email.setWhatId(opp.Id);
            
            email.setFileAttachments(attachments);
            email.setSaveAsActivity(false);
            
            
            Messaging.sendEmail(
            new Messaging.SingleEmailMessage[] { email }
            );
            
            System.debug('Buyer document email sent successfully');
        }
    }
    
    
    public class Request {
        
        @InvocableVariable(required=true)
        public Id opportunityId;
        
        
        @InvocableVariable(required=true)
        public Id emailTemplateId;
    }
}