import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTasks from '@salesforce/apex/TaskChecklistController.getTasks';
import updateTaskStatus from '@salesforce/apex/TaskChecklistController.updateTaskStatus';

// Standard Task Status values this component works with
const STATUS_IN_PROGRESS = 'In Progress';
const STATUS_COMPLETED = 'Completed';

export default class TaskChecklist extends NavigationMixin(LightningElement) {
    @api recordId;

    tasks = [];
    wiredTasksResult; // kept so we can call refreshApex() after an update or manual refresh

    @wire(getTasks, { recordId: '$recordId' })
    wiredTasks(result) {
        this.wiredTasksResult = result;
        if (result.data) {
            this.tasks = result.data.map((task) => this.decorateTask(task));
            this.generateTaskUrls();
        } else if (result.error) {
            this.showToast('Error loading tasks', this.reduceError(result.error), 'error');
        }
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

    // Converts the "YYYY-MM-DD" string Apex returns for a Date field into "M/D/YYYY"
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

    // Opens Salesforce's own standard Task edit window
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

    // The standard edit window above is outside this component's control. This manual refresh is the guaranteed way to pull in any changes made there.
    handleRefreshClick() {
        if (!this.wiredTasksResult) {
            return;
        }
        refreshApex(this.wiredTasksResult).then(() => {
            this.showToast('Refreshed', 'Task list updated.', 'success');
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

        updateTaskStatus({ taskId, status })
            .then(() => refreshApex(this.wiredTasksResult))
            .then(() => {
                // On success the wire re-fires and decorateTask() rebuilds every row based on the new Status, which is what flips the icon/buttons/color.
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