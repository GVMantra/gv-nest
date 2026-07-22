public with sharing class TaskChecklistController {

    //Returns all Tasks whose WhatId is the current Opportunity record.
    @AuraEnabled(cacheable=true)
    public static List<Task> getTasks(Id recordId) {
        return [SELECT Id, Subject, Status, ActivityDate, OwnerId, Owner.Name FROM Task WHERE WhatId = :recordId ORDER BY ActivityDate ASC NULLS LAST];
    }

    // Updates a single Task's Status field. Called when the user clicks the Complete or Pause button.
    @AuraEnabled
    public static void updateTaskStatus(Id taskId, String status) {
        update new Task(Id = taskId, Status = status);
    }

}