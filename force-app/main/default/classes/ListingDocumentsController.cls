public with sharing class ListingDocumentsController {
    @AuraEnabled(cacheable=true)
    public static List<Document_Type__mdt> getDocumentTypes() {
        return [
            SELECT Document_Type__c,
                   Display_Order__c,
                   Mandatory__c
            FROM Document_Type__mdt WHERE Active__c = true ORDER BY Display_Order__c
        ];
    }
    @AuraEnabled(cacheable=true)
    public static List<Opportunity_Document__c> getOpportunityDocuments(Id opportunityId){
        
        return [
        SELECT Id,
               Document_Type__c,
               Uploaded_On__c,
               Uploaded_By__r.Name,
               (
                    SELECT ContentDocumentId,
                           ContentDocument.Title
                    FROM ContentDocumentLinks
                    ORDER BY SystemModstamp DESC
                    LIMIT 1
               )
        FROM Opportunity_Document__c
        WHERE Opportunity__c = :opportunityId
    ];
    }
    @AuraEnabled
    public static Id createOpportunityDocument(
        Id opportunityId,
    String documentType
    ) {
        
        Opportunity_Document__c doc = new Opportunity_Document__c();
        
        doc.Opportunity__c = opportunityId;
        doc.Document_Type__c = documentType;
        doc.Uploaded_On__c = System.now();
        doc.Uploaded_By__c = UserInfo.getUserId();
        
        insert doc;
        
        return doc.Id;
    }
    @AuraEnabled
    public static void linkFileToOpportunityDocument(
        Id contentDocumentId,
    Id opportunityDocumentId
    ) {
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        
        cdl.ContentDocumentId = contentDocumentId;
        cdl.LinkedEntityId = opportunityDocumentId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        
        insert cdl;
    }
}