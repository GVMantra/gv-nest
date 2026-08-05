public with sharing class BuyerRequirementSearchAction {

    public class SearchRequest {

        @InvocableVariable(required=true)
        public Id opportunityId;

        @InvocableVariable
        public String preferredPropertyType;

        @InvocableVariable
        public Boolean gymRequired;

        @InvocableVariable
        public Decimal minimumBudget;

        @InvocableVariable
        public Decimal maximumBudget;

        @InvocableVariable
        public Integer minimumBathrooms;
    }

    @InvocableMethod(label='Search Buyer Requirements')
    public static List<List<Buyer_Requirement__c>> searchBuyerRequirements(List<SearchRequest> requests) {

        if (requests == null || requests.isEmpty()) {
            return new List<List<Buyer_Requirement__c>>();
        }

        SearchRequest req = requests[0];

        // Get Buyer Requirements already associated with this Opportunity
        Set<Id> existingBuyerAccountIds = new Set<Id>();

        for (Interested_Buyer__c ib : [
            SELECT Buyer_Account__c
            FROM Interested_Buyer__c
            WHERE Opportunity__c = :req.opportunityId
            AND Buyer_Account__c != null
        ]) {
            existingBuyerAccountIds.add(ib.Buyer_Account__c);
        }

        String query =
            'SELECT Id, Name, Account__c,' +
            ' Preferred_Property_Type__c,' +
            ' Gym_Required__c,' +
            ' Minimum_Budget__c,' +
            ' Maximum_Budget__c,' +
            ' Minimum_Bathrooms__c,' +
            ' Active__c ' +
            'FROM Buyer_Requirement__c ' +
            'WHERE Active__c = TRUE';

        Map<String, Object> bindVariables = new Map<String, Object>();

        if (!existingBuyerAccountIds.isEmpty()) {
            query += ' AND Account__c NOT IN :existingBuyerAccountIds';
            bindVariables.put('existingBuyerAccountIds', existingBuyerAccountIds);
        }

        if (String.isNotBlank(req.preferredPropertyType)) {
            query += ' AND Preferred_Property_Type__c = :preferredPropertyType';
            bindVariables.put('preferredPropertyType', req.preferredPropertyType);
        }

        if (req.gymRequired == True) {
            query += ' AND Gym_Required__c = :gymRequired';
            bindVariables.put('gymRequired', req.gymRequired);
        }

        if (req.maximumBudget != null) {
            query += ' AND (Minimum_Budget__c = NULL OR Minimum_Budget__c <= :maximumBudget)';
            bindVariables.put('maximumBudget', req.maximumBudget);
          }

        if (req.minimumBudget != null) {
            query += ' AND (Maximum_Budget__c = NULL OR Maximum_Budget__c >= :minimumBudget)';
            bindVariables.put('minimumBudget', req.minimumBudget);
           }

        if (req.minimumBathrooms != null) {
            query += ' AND Minimum_Bathrooms__c >= :minimumBathrooms';
            bindVariables.put('minimumBathrooms', req.minimumBathrooms);
        }

        List<Buyer_Requirement__c> buyerRequirements =
            (List<Buyer_Requirement__c>) Database.queryWithBinds(
                query,
                bindVariables,
                AccessLevel.SYSTEM_MODE
            );

        List<List<Buyer_Requirement__c>> results = new List<List<Buyer_Requirement__c>>();
        results.add(buyerRequirements);

        return results;
    }
}