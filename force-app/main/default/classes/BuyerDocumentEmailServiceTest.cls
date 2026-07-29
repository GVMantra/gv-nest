@IsTest(SeeAllData=true)
private class BuyerDocumentEmailServiceTest {
    
    @IsTest
    static void testSuccessfulEmailWithDocuments() {
        
        // Get an existing Opportunity with an Accepted Buyer
        List<Opportunity> opportunities = [
            SELECT Id,
                   Accepted_Buyer__c
            FROM Opportunity
            WHERE Accepted_Buyer__c != null
            LIMIT 1
        ];
        
        System.assert(
            !opportunities.isEmpty(),
        'An Opportunity with an Accepted Buyer is required.'
            );
        
        Opportunity opp = opportunities[0];
        
        
        // Verify that the Accepted Buyer has a Contact with Email
        List<Contact> contacts = [
            SELECT Id,
                   Email
            FROM Contact
            WHERE AccountId = :opp.Accepted_Buyer__c
            AND Email != null
            LIMIT 1
        ];
        
        System.assert(
            !contacts.isEmpty(),
        'The Accepted Buyer must have a Contact with an Email.'
            );
        
        
        // Get the existing Email Template
        List<EmailTemplate> templates = [
            SELECT Id,
                   Name
            FROM EmailTemplate
            WHERE Name = 'Buyer Documents Requested'
            LIMIT 1
        ];
        
        System.assert(
            !templates.isEmpty(),
        'Buyer Documents Requested Email Template was not found.'
            );
        
        
        // Create Opportunity Document
        Opportunity_Document__c documentRecord =
            new Opportunity_Document__c(
            Opportunity__c = opp.Id,
        Document_Type__c = 'Sale Deed'
            );
        
        insert documentRecord;
        
        
        // Create Salesforce File
        ContentVersion fileVersion =
            new ContentVersion(
            Title = 'Test Buyer Document',
        PathOnClient = 'TestBuyerDocument.pdf',
        VersionData = Blob.valueOf(
            'Test document content'
            )
            );
        
        insert fileVersion;
        
        
        // Get ContentDocumentId
        fileVersion = [
            SELECT Id,
                   ContentDocumentId
            FROM ContentVersion
            WHERE Id = :fileVersion.Id
        ];
        
        
        // Link File to Opportunity Document
        ContentDocumentLink fileLink =
            new ContentDocumentLink(
            ContentDocumentId =
            fileVersion.ContentDocumentId,
        LinkedEntityId =
            documentRecord.Id,
        ShareType = 'V',
        Visibility = 'AllUsers'
            );
        
        insert fileLink;
        
        
        // Create request for Invocable Apex
        BuyerDocumentEmailService.Request request =
            new BuyerDocumentEmailService.Request();
        
        request.opportunityId = opp.Id;
        request.emailTemplateId = templates[0].Id;
        
        
        Test.startTest();
        
        BuyerDocumentEmailService.sendBuyerDocuments(
        new List<BuyerDocumentEmailService.Request>{
            request
        }
        );
        
        Test.stopTest();
        
        
        // Verify Opportunity Document
        Opportunity_Document__c createdDocument = [
            SELECT Id,
                   Opportunity__c,
                   Document_Type__c
            FROM Opportunity_Document__c
            WHERE Id = :documentRecord.Id
        ];
        
        System.assertEquals(
            opp.Id,
        createdDocument.Opportunity__c,
        'The Opportunity Document should be linked to the correct Opportunity.'
            );
        
        System.assertEquals(
            'Sale Deed',
        createdDocument.Document_Type__c,
        'The correct Document Type should be used.'
            );
        
        
        // Verify that the Salesforce File is linked
        List<ContentDocumentLink> linkedFiles = [
            SELECT Id,
                   ContentDocumentId,
                   LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :documentRecord.Id
        ];
        
        System.assertEquals(
            1,
        linkedFiles.size(),
        'One Salesforce File should be linked to the Opportunity Document.'
            );
    }
    
    
    @IsTest
    static void testNullRequestList() {
        
        Test.startTest();
        
        BuyerDocumentEmailService.sendBuyerDocuments(
            null
            );
        
        Test.stopTest();
        
        System.assertEquals(
            0,
        Limits.getEmailInvocations(),
        'No email should be invoked for a null request.'
            );
    }
    
    
    @IsTest
    static void testEmptyRequestList() {
        
        Test.startTest();
        
        BuyerDocumentEmailService.sendBuyerDocuments(
            new List<BuyerDocumentEmailService.Request>()
            );
        
        Test.stopTest();
        
        System.assertEquals(
            0,
        Limits.getEmailInvocations(),
        'No email should be invoked for an empty request.'
            );
    }
    
    
    @IsTest
    static void testMissingOpportunityId() {
        
        BuyerDocumentEmailService.Request request =
            new BuyerDocumentEmailService.Request();
        
        request.opportunityId = null;
        request.emailTemplateId = UserInfo.getUserId();
        
        
        Test.startTest();
        
        BuyerDocumentEmailService.sendBuyerDocuments(
        new List<BuyerDocumentEmailService.Request>{
            request
        }
        );
        
        Test.stopTest();
        
        System.assertEquals(
            0,
        Limits.getEmailInvocations(),
        'No email should be invoked when Opportunity Id is missing.'
            );
    }
    
    
    @IsTest
    static void testMissingEmailTemplateId() {
        
        List<Opportunity> opportunities = [
            SELECT Id
            FROM Opportunity
            LIMIT 1
        ];
        
        System.assert(
            !opportunities.isEmpty(),
        'An Opportunity is required.'
            );
        
        
        BuyerDocumentEmailService.Request request =
            new BuyerDocumentEmailService.Request();
        
        request.opportunityId = opportunities[0].Id;
        request.emailTemplateId = null;
        
        
        Test.startTest();
        
        BuyerDocumentEmailService.sendBuyerDocuments(
        new List<BuyerDocumentEmailService.Request>{
            request
        }
        );
        
        Test.stopTest();
        
        System.assertEquals(
            0,
        Limits.getEmailInvocations(),
        'No email should be invoked when Email Template Id is missing.'
            );
    }
}