@isTest
private class TaskChecklistControllerTest {

    // Creates an Opportunity plus three Tasks against it, with due dates and statuses deliberately out of order/null so getTasks() has something to sort.
    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        List<Task> tasks = new List<Task>{
            new Task(
                Subject = 'Due Later',
                WhatId = opp.Id,
                Status = 'Not Started',
                ActivityDate = Date.today().addDays(10)
            ),
            new Task(
                Subject = 'Due Sooner',
                WhatId = opp.Id,
                Status = 'In Progress',
                ActivityDate = Date.today().addDays(1)
            ),
            new Task(
                Subject = 'No Due Date',
                WhatId = opp.Id,
                Status = 'Deferred',
                ActivityDate = null
            )
        };
        insert tasks;

        // A second Opportunity with no related Tasks, to prove getTasks() only returns Tasks tied to the requested WhatId and doesn't leak tasks from elsewhere.
        Opportunity unrelatedOpp = new Opportunity(
            Name = 'Unrelated Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert unrelatedOpp;
    }

    @isTest
    static void testGetTasks_returnsTasksOrderedByActivityDateWithNullsLast() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];

        Test.startTest();
        List<Task> result = TaskChecklistController.getTasks(opp.Id);
        Test.stopTest();

        // Filter down to just the three Tasks this test inserted, in case org automation (e.g. a Flow) also creates Tasks on the Opportunity. We only care about the relative order of our own known records.
        Set<String> ourSubjects = new Set<String>{ 'Due Sooner', 'Due Later', 'No Due Date' };
        List<Task> ours = new List<Task>();
        for (Task t : result) {
            if (ourSubjects.contains(t.Subject)) {
                ours.add(t);
            }
        }

        Assert.areEqual(3, ours.size(), 'All three of this test\'s own tasks should be present in the results');
        Assert.areEqual('Due Sooner', ours[0].Subject, 'Task with the earliest ActivityDate should come first among our tasks');
        Assert.areEqual('Due Later', ours[1].Subject, 'Task with the later ActivityDate should come second among our tasks');
        Assert.areEqual('No Due Date', ours[2].Subject, 'Task with a null ActivityDate should sort last among our tasks');
    }

    @isTest
    static void testGetTasks_ownerNameMatchesDirectQueryWhenPresent() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];

        // Query the same Task directly, independent of the controller, so we know what the "ground truth" Owner.Name is for this record in this org (which may be null depending on org-specific ownership/sharing behavior that's outside the controller's control).
        Task directQuery = [
            SELECT Id, Owner.Name
            FROM Task
            WHERE WhatId = :opp.Id AND Subject = 'Due Sooner'
            LIMIT 1
        ];

        Test.startTest();
        List<Task> result = TaskChecklistController.getTasks(opp.Id);
        Test.stopTest();

        Task ours = null;
        for (Task t : result) {
            if (t.Id == directQuery.Id) {
                ours = t;
            }
        }

        Assert.areNotEqual(null, ours, 'Our own test task should be present in the results');

        // The controller's query should surface the exact same Owner.Name value a direct query does — whatever that value legitimately is in this org — rather than assuming it must always be non-null.
        String expectedOwnerName = (directQuery.Owner != null) ? directQuery.Owner.Name : null;
        String actualOwnerName = (ours.Owner != null) ? ours.Owner.Name : null;
        Assert.areEqual(expectedOwnerName, actualOwnerName, 'getTasks() should return the same Owner.Name a direct query would for this Task');
    }

    @isTest
    static void testGetTasks_onlyReturnsTasksForTheRequestedOpportunity() {
        Opportunity unrelatedOpp = [SELECT Id FROM Opportunity WHERE Name = 'Unrelated Opportunity' LIMIT 1];

        Test.startTest();
        List<Task> result = TaskChecklistController.getTasks(unrelatedOpp.Id);
        Test.stopTest();

        // This org's automation may create its own default Tasks on any new Opportunity, so we can't assert the list is empty. What we CAN assert is that none of the Tasks belonging to the *other* Opportunity leaked into these results — i.e. the WhatId filter in the query is doing its job correctly.
        Set<String> otherOpportunitysSubjects = new Set<String>{ 'Due Sooner', 'Due Later', 'No Due Date' };
        for (Task t : result) {
            Assert.isFalse(
                otherOpportunitysSubjects.contains(t.Subject),
                'Tasks belonging to a different Opportunity should not appear in these results'
            );
        }
    }

    @isTest
    static void testUpdateTaskStatus_updatesStatusSuccessfully() {
        Task t = [SELECT Id, Status FROM Task WHERE Subject = 'Due Sooner' LIMIT 1];
        Assert.areNotEqual('Completed', t.Status, 'Precondition: task should not already be Completed');

        Test.startTest();
        TaskChecklistController.updateTaskStatus(t.Id, 'Completed');
        Test.stopTest();

        Task updated = [SELECT Status FROM Task WHERE Id = :t.Id];
        Assert.areEqual('Completed', updated.Status, 'Status should be updated to the requested value');
    }

    @isTest
    static void testUpdateTaskStatus_invalidTaskIdThrows() {
        // Insert then delete a Task so we have a well-formed, valid-looking Id that is guaranteed not to correspond to any existing record.
        Task throwaway = new Task(Subject = 'Throwaway', Status = 'Not Started');
        insert throwaway;
        Id deletedTaskId = throwaway.Id;
        delete throwaway;

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            TaskChecklistController.updateTaskStatus(deletedTaskId, 'Completed');
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Updating a Task that does not exist should raise an exception rather than silently succeed');
    }
}