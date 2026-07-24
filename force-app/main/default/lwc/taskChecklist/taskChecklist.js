import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Standard Task Status values this component works with
const STATUS_IN_PROGRESS = 'In Progress';
const STATUS_COMPLETED = 'Completed';

const TASK_FIELDS = ['Task.Subject', 'Task.Status', 'Task.ActivityDate', 'Task.OwnerId', 'Task.Owner.Name'];

export default class TaskChecklist extends NavigationMixin(LightningElement) {
    @api recordId;

    tasks = [];

    // This wire is LDS-native. The standard edit window writes through Lightning Data Service's shared record cache when it saves, and any other LDS-native wire reading one of those same records — like this one — is automatically kept in sync by the platform.
    @wire(getRelatedListRecords, {
        parentRecordId: '$recordId',
        relatedListId: 'Tasks',
        fields: TASK_FIELDS
    })
    wiredTasks({ data, error }) {
        if (data) {
            this.tasks = data.records
                .map((record) => this.flattenRecord(record))
                .sort((a, b) => this.compareByActivityDate(a, b))
                .map((task) => this.decorateTask(task));
            this.generateTaskUrls();
        } else if (error) {
            this.showToast('Error loading tasks', this.reduceError(error), 'error');
        }
    }

    flattenRecord(record) {
        const fields = record.fields;

        const ownerName =
            fields.Owner &&
            fields.Owner.value &&
            fields.Owner.value.fields &&
            fields.Owner.value.fields.Name
                ? fields.Owner.value.fields.Name.value
                : undefined;

        return {
            Id: record.id,
            Subject: fields.Subject?.value,
            Status: fields.Status?.value,
            ActivityDate: fields.ActivityDate?.value,
            OwnerId: fields.OwnerId?.value,
            Owner: {
                Name: ownerName
            }
        };
    }

    compareByActivityDate(a, b) {
        if (!a.ActivityDate && !b.ActivityDate) {
            return 0;
        }
        if (!a.ActivityDate) {
            return 1;
        }
        if (!b.ActivityDate) {
            return -1;
        }
        return a.ActivityDate < b.ActivityDate ? -1 : a.ActivityDate > b.ActivityDate ? 1 : 0;
    }

    get noTasks() {
        return this.tasks.length === 0;
    }

    decorateTask(task) {
        const hasDueDate = !!task.ActivityDate;
        const isCompleted = task.Status === STATUS_COMPLETED;
        const isInProgress = task.Status === STATUS_IN_PROGRESS;

        return {
            ...task,
            isProcessing: false,
            assignmentLabel: this.getAssignmentLabel(task),
            dueDateFormatted: this.formatDueDate(task.ActivityDate),
            cssClass: this.getCssClass(task.Status),
            taskUrl: '#',

            showActionsRow: !isCompleted,
            // Complete and Play still require a due date to be set, and Play is additionally hidden once the task is already In Progress.
            showCompleteButton: hasDueDate && !isCompleted,
            showPlayButton: hasDueDate && !isCompleted && !isInProgress
        };
    }

    generateTaskUrls() {
        this.tasks.forEach((task) => {
            const pageReference = {
                type: 'standard__recordPage',
                attributes: {
                    recordId: task.Id,
                    objectApiName: 'Task',
                    actionName: 'view'
                }
            };
            this[NavigationMixin.GenerateUrl](pageReference).then((url) => {
                this.tasks = this.tasks.map((t) =>
                    t.Id === task.Id ? { ...t, taskUrl: url } : t
                );
            });
        });
    }

    // Null check: Task.OwnerId is normally required on a Task, but we guard anyway in case Owner wasn't queried/available for some reason.
    getAssignmentLabel(task) {
        if (task && task.Owner && task.Owner.Name) {
            return ` is assigned to ${task.Owner.Name}`;
        }
        return ' - Unassigned';
    }

    // Converts the "YYYY-MM-DD" string the UI API returns for a Date field into "M/D/YYYY"
    formatDueDate(activityDate) {
        if (!activityDate) {
            return 'Not Populated';
        }
        const [year, month, day] = activityDate.split('-');
        return `${Number(month)}/${Number(day)}/${year}`;
    }

    getCssClass(status) {
        let cssClass = 'task-item';
        if (status === STATUS_COMPLETED) {
            cssClass += ' task-completed';
        } else if (status === STATUS_IN_PROGRESS) {
            cssClass += ' task-in-progress';
        }
        return cssClass;
    }

    handleTaskClick(event) {
        const isModifiedClick =
            event.ctrlKey || event.metaKey || event.shiftKey || event.button === 1;
        if (isModifiedClick) {
            return; // let the browser handle it natively via href
        }

        event.preventDefault();
        const taskId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: taskId,
                objectApiName: 'Task',
                actionName: 'view'
            }
        });
    }

    // Opens Salesforce's own standard Task edit window. Saving there writes through Lightning Data Service, and the getRelatedListRecords wire above picks up that change automatically.
    handleEditClick(event) {
        const taskId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: taskId,
                objectApiName: 'Task',
                actionName: 'edit'
            }
        });
    }

    handleComplete(event) {
        this.changeStatus(event.currentTarget.dataset.id, STATUS_COMPLETED);
    }

    handlePlay(event) {
        this.changeStatus(event.currentTarget.dataset.id, STATUS_IN_PROGRESS);
    }

    changeStatus(taskId, status) {
        const task = this.tasks.find((t) => t.Id === taskId);

        if (!task || task.isProcessing) {
            return;
        }

        this.setProcessing(taskId, true);

        // updateRecord writes through the same LDS cache the standard edit window uses, so this alone is enough to make the getRelatedListRecords wire above re-fire with fresh data.
        updateRecord({ fields: { Id: taskId, Status: status } })
            .then(() => {
                this.showToast('Success', 'Task updated.', 'success');
            })
            .catch((error) => {
                this.showToast('Error updating task', this.reduceError(error), 'error');
                this.setProcessing(taskId, false);
            });
    }

    setProcessing(taskId, isProcessing) {
        this.tasks = this.tasks.map((task) =>
            task.Id === taskId ? { ...task, isProcessing } : task
        );
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        return (error && error.body && error.body.message) || 'Unknown error';
    }
}