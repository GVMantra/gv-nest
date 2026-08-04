@IsTest
private class BuyerRequirementSearchActionTest {

    @TestSetup
    static void setupData() {

        Account acc = new Account(
            Name = 'Test Buyer Account'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Buyer_Requirement__c br1 = new Buyer_Requirement__c(
            Account__c = acc.Id,
            Preferred_Property_Type__c = 'Apartment',
            Preferred_Location__c = 'Delhi',
            Minimum_Budget__c = 100000,
            Maximum_Budget__c = 300000,
            Minimum_Bathrooms__c = 2,
            Gym_Required__c = true,
            Active__c = true
        );

        Buyer_Requirement__c br2 = new Buyer_Requirement__c(
            Account__c = acc.Id,
            Preferred_Property_Type__c = 'Apartment',
            Preferred_Location__c = 'Delhi',
            Minimum_Budget__c = 100000,
            Maximum_Budget__c = 300000,
            Minimum_Bathrooms__c = 2,
            Gym_Required__c = true,
            Active__c = true
        );

        Buyer_Requirement__c inactiveBR = new Buyer_Requirement__c(
            Account__c = acc.Id,
            Preferred_Property_Type__c = 'Apartment',
            Preferred_Location__c = 'Delhi',
            Minimum_Budget__c = 100000,
            Maximum_Budget__c = 300000,
            Minimum_Bathrooms__c = 2,
            Gym_Required__c = true,
            Active__c = false
        );

        insert new List<Buyer_Requirement__c>{
            br1,
            br2,
            inactiveBR
        };

        Interested_Buyer__c ib = new Interested_Buyer__c(
            Buyer_Account__c = acc.id,
            Opportunity__c = opp.Id,
            Buyer_Requirement__c = br2.Id,
            Status__c = 'New'
        );
        insert ib;
    }

    @IsTest
    static void testSearchBuyerRequirements() {

        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            LIMIT 1
        ];

        BuyerRequirementSearchAction.SearchRequest req =
            new BuyerRequirementSearchAction.SearchRequest();

        req.opportunityId = opp.Id;
        req.preferredPropertyType = 'Apartment';
        req.gymRequired = true;
        req.minimumBudget = 150000;
        req.maximumBudget = 250000;
        req.minimumBathrooms = 2;

        Test.startTest();

        List<List<Buyer_Requirement__c>> results =
            BuyerRequirementSearchAction.searchBuyerRequirements(
                new List<BuyerRequirementSearchAction.SearchRequest>{ req }
            );

        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(1, results[0].size());

        Buyer_Requirement__c returnedBR = results[0][0];

        System.assertEquals(true, returnedBR.Active__c);
        System.assertEquals('Apartment', returnedBR.Preferred_Property_Type__c);
        System.assertEquals(true, returnedBR.Gym_Required__c);
    }

    @IsTest
    static void testEmptyRequestList() {

        Test.startTest();

        List<List<Buyer_Requirement__c>> results =
            BuyerRequirementSearchAction.searchBuyerRequirements(
                new List<BuyerRequirementSearchAction.SearchRequest>()
            );

        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testNullRequestList() {

        Test.startTest();

        List<List<Buyer_Requirement__c>> results =
            BuyerRequirementSearchAction.searchBuyerRequirements(null);

        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testNoMatchingRecords() {

        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            LIMIT 1
        ];

        BuyerRequirementSearchAction.SearchRequest req =
            new BuyerRequirementSearchAction.SearchRequest();

        req.opportunityId = opp.Id;
        req.preferredPropertyType = 'Villa';

        Test.startTest();

        List<List<Buyer_Requirement__c>> results =
            BuyerRequirementSearchAction.searchBuyerRequirements(
                new List<BuyerRequirementSearchAction.SearchRequest>{ req }
            );

        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(0, results[0].size());
    }
}