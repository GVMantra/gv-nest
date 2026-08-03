@IsTest(SeeAllData=true)
private class BuyerDocumentEmailServiceTest {
    
    @IsTest
    static void testSuccessfulEmailWithDocuments() {
        
        // Create Buyer Account
        Account buyerAccount = new Account(
            Name = 'Test Buyer Account'
            );
        insert buyerAccount;
        
        
        // Create Buyer Contact
        Contact buyerContact = new Contact(
            FirstName = 'Test',
        LastName = 'Buyer',
        Email = 'buyer@test.com',
        AccountId = buyerAccount.Id
            );
        insert buyerContact;
        
        
        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(30),
        AccountId = buyerAccount.Id
            );
        insert opp;
        
        
        // Create Buyer Requirement
        Buyer_Requirement__c buyerRequirement =
            new Buyer_Requirement__c(
            Account__c = buyerAccount.Id,
        Preferred_Location__c = 'Gurgaon',
        Maximum_Budget__c = 5000000,
        Active__c = true
            );
        
        insert buyerRequirement;
        
        
        // Create Interested Buyer
        Interested_Buyer__c interestedBuyer =
            new Interested_Buyer__c(
            Opportunity__c = opp.Id,
        Buyer_Account__c = buyerAccount.Id,
        Buyer_Requirement__c = buyerRequirement.Id,
        Status__c = 'Documents Requested'
            );
        
        insert interestedBuyer;
        
        
        // Get Email Template
        EmailTemplate template = [
            SELECT Id
            FROM EmailTemplate
            WHERE Name = 'Buyer Documents Requested'
            LIMIT 1
        ];
        
        
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
        
        
        // Link File with Opportunity Document
        ContentDocumentLink fileLink =
            new ContentDocumentLink(
            ContentDocumentId = fileVersion.ContentDocumentId,
        LinkedEntityId = documentRecord.Id,
        ShareType = 'V',
        Visibility = 'AllUsers'
            );
        
        insert fileLink;
        
        
        // Prepare Apex Request
        BuyerDocumentEmailService.Request request =
            new BuyerDocumentEmailService.Request();
        
        request.opportunityId = opp.Id;
        request.emailTemplateId = template.Id;
        
        
        Test.startTest();
        
        BuyerDocumentEmailService.sendBuyerDocuments(
        new List<BuyerDocumentEmailService.Request>{
            request
        }
        );
        
        Test.stopTest();
        
        
        // Verify File Link
        List<ContentDocumentLink> linkedFiles = [
            SELECT Id,
                   ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :documentRecord.Id
        ];
        
        System.assertEquals(
            1,
        linkedFiles.size(),
        'Salesforce File should be linked with Opportunity Document'
            );
    }
    
    
    @IsTest
    static void testNullRequestList() {
        
        Test.startTest();
        
        BuyerDocumentEmailService.sendBuyerDocuments(null);
        
        Test.stopTest();
        
        System.assertEquals(
            0,
        Limits.getEmailInvocations()
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
        Limits.getEmailInvocations()
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
        Limits.getEmailInvocations()
            );
    }
    
    
    @IsTest
    static void testMissingEmailTemplateId() {
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(30)
            );
        
        insert opp;
        
        
        BuyerDocumentEmailService.Request request =
            new BuyerDocumentEmailService.Request();
        
        request.opportunityId = opp.Id;
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
        Limits.getEmailInvocations()
            );
    }
}