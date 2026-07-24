@isTest
private class ListingDocumentsControllerTest {
    
    // Create common test data once for all test methods
    @testSetup
    static void setupData() {
        
        // Create Test Account
        Account acc = new Account(
            Name = 'Test Account'
            );
        insert acc;
        
        // Create Test Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(10),
        AccountId = acc.Id
            );
        insert opp;
    }
    
    // Test getDocumentTypes() method
    @isTest
    static void testGetDocumentTypes() {
        
        Test.startTest();
        
        List<Document_Type__mdt> docs =
            ListingDocumentsController.getDocumentTypes();
        
        Test.stopTest();
        
        // Verify method executed successfully
        System.assertNotEquals(null, docs);
    }
    
    // Test createOpportunityDocument() method
    @isTest
    static void testCreateOpportunityDocument() {
        
        // Get test opportunity
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
        
        // Verify Opportunity Document record is created
        System.assertNotEquals(null, docId);
        
        Opportunity_Document__c doc = [
            SELECT Opportunity__c,
                   Document_Type__c,
                   Uploaded_By__c
            FROM Opportunity_Document__c
            WHERE Id = :docId
        ];
        
        // Verify field values
        System.assertEquals(opp.Id, doc.Opportunity__c);
        System.assertEquals('Sale Deed', doc.Document_Type__c);
    }
    
    // Test getOpportunityDocuments() method
    @isTest
    static void testGetOpportunityDocuments() {
        
        // Get test opportunity
        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            LIMIT 1
        ];
        
        // Create Opportunity Document
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
        
        // Verify document is returned
        System.assertEquals(1, docs.size());
    }
    
    // Test linkFileToOpportunityDocument() method
    @isTest
    static void testLinkFileToOpportunityDocument() {
        
        // Get test opportunity
        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            LIMIT 1
        ];
        
        // Create Opportunity Document
        Opportunity_Document__c doc =
            new Opportunity_Document__c(
            Opportunity__c = opp.Id,
        Document_Type__c = 'Sale Deed',
        Uploaded_On__c = System.now(),
        Uploaded_By__c = UserInfo.getUserId()
            );
        
        insert doc;
        
        // Create a test Salesforce File
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
        PathOnClient = 'Test.pdf',
        VersionData = Blob.valueOf('Test Data')
            );
        
        insert cv;
        
        // Get ContentDocumentId from ContentVersion
        cv = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];
        
        Test.startTest();
        
        // Link File with Opportunity Document
        ListingDocumentsController.linkFileToOpportunityDocument(
            cv.ContentDocumentId,
        doc.Id
            );
        
        Test.stopTest();
        
        // Verify ContentDocumentLink is created
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