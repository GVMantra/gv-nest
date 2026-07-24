@isTest
private class TestListingDocumentController {
    
    // Create common test data
    @testSetup
    static void setupData() {
        
        Account acc = new Account(
            Name = 'Test Account'
            );
        insert acc;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(10),
        AccountId = acc.Id
            );
        insert opp;
    }
    
    // Test getDocumentTypes()
    @isTest
    static void testGetDocumentTypes() {
        
        Test.startTest();
        
        List<Document_Type__mdt> docs =
            ListingDocumentsController.getDocumentTypes();
        
        Test.stopTest();
        
        System.assertNotEquals(null, docs);
    }
    
    // Test createOpportunityDocument()
    @isTest
    static void testCreateOpportunityDocument() {
        
        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            LIMIT 1
        ];
        
        Test.startTest();
        
        Id docId =
            ListingDocumentsController.createOpportunityDocument(
            opp.Id,
        'Sale Deed'
            );
        
        Test.stopTest();
        
        System.assertNotEquals(null, docId);
        
        Opportunity_Document__c doc = [
            SELECT Opportunity__c,
                   Document_Type__c,
                   Uploaded_By__c
            FROM Opportunity_Document__c
            WHERE Id = :docId
        ];
        
        System.assertEquals(opp.Id, doc.Opportunity__c);
        System.assertEquals('Sale Deed', doc.Document_Type__c);
    }
    
    // Test getOpportunityDocuments()
    @isTest
    static void testGetOpportunityDocuments() {
        
        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            LIMIT 1
        ];
        
        Opportunity_Document__c doc =
            new Opportunity_Document__c(
            Opportunity__c = opp.Id,
        Document_Type__c = 'Sale Deed',
        Uploaded_On__c = System.now(),
        Uploaded_By__c = UserInfo.getUserId()
            );
        
        insert doc;
        
        Test.startTest();
        
        List<Opportunity_Document__c> docs =
            ListingDocumentsController.getOpportunityDocuments(
            opp.Id
            );
        
        Test.stopTest();
        
        System.assertEquals(1, docs.size());
    }
    
    // Test linkFileToOpportunityDocument()
    @isTest
    static void testLinkFileToOpportunityDocument() {
        
        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            LIMIT 1
        ];
        
        Opportunity_Document__c doc =
            new Opportunity_Document__c(
            Opportunity__c = opp.Id,
        Document_Type__c = 'Sale Deed',
        Uploaded_On__c = System.now(),
        Uploaded_By__c = UserInfo.getUserId()
            );
        
        insert doc;
        
        // Create test file
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
        PathOnClient = 'Test.pdf',
        VersionData = Blob.valueOf('Test Data')
            );
        
        insert cv;
        
        cv = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];
        
        Test.startTest();
        
        ListingDocumentsController.linkFileToOpportunityDocument(
            cv.ContentDocumentId,
        doc.Id
            );
        
        Test.stopTest();
        
        ContentDocumentLink cdl = [
            SELECT Id,
                   LinkedEntityId,
                   ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :doc.Id
            LIMIT 1
        ];
        
        System.assertEquals(doc.Id, cdl.LinkedEntityId);
        System.assertEquals(cv.ContentDocumentId, cdl.ContentDocumentId);
    }
}