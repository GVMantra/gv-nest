import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTasks from '@salesforce/apex/TaskChecklistController.getTasks';
import updateTaskStatus from '@salesforce/apex/TaskChecklistController.updateTaskStatus';
import { getObjectInfo, getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';
import TASK_OBJECT from '@salesforce/schema/Task';

// Standard Task Status values this component works with
const STATUS_NOT_STARTED = 'Not Started';
const STATUS_IN_PROGRESS = 'In Progress';
const STATUS_COMPLETED = 'Completed';
const STATUS_DEFERRED = 'Deferred';

export default class TaskChecklist extends NavigationMixin(LightningElement) {
    @api recordId;

    tasks = [];
    wiredTasksResult; // kept so we can call refreshApex() after an update

    // Controls the "Edit Task" modal
    showEditModal = false;
    editingTaskId;
    editingTaskOwnerId; // bound to the Assigned To record-picker, since OwnerId can't be edited via lightning-input-field
    isModalLoading = false; // drives the spinner overlay shown while the form's record data loads

    // --- Metadata pre-warming (reduces modal open lag) ---
    // lightning-input-field is slow the *first* time it renders a given
    // object's fields, because it triggers a describe/picklist fetch on
    // demand. Wiring the same calls here, as soon as this component loads
    // on the Opportunity page, lets Lightning Data Service cache that
    // metadata early, well before the modal ever opens.
    taskRecordTypeId;

    @wire(getObjectInfo, { objectApiName: TASK_OBJECT })
    taskObjectInfo({ data }) {
        if (data) {
            this.taskRecordTypeId = data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValuesByRecordType, {
        objectApiName: TASK_OBJECT,
        recordTypeId: '$taskRecordTypeId'
    })
    taskPicklistValues; // result isn't used directly — wiring it is what triggers and caches the fetch

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
        return {
            ...task,
            isProcessing: false,
            assignmentLabel: this.getAssignmentLabel(task),
            dueDateFormatted: this.formatDueDate(task.ActivityDate),
            cssClass: this.getCssClass(task.Status),
            taskUrl: '#',

            // Status buttons are shown by default now (no edit-toggle gating them)
            showCompleteButton:
                task.Status === STATUS_IN_PROGRESS || task.Status === STATUS_DEFERRED,
            showPlayPauseButton: task.Status !== STATUS_COMPLETED,
            playPauseIcon: task.Status === STATUS_IN_PROGRESS ? 'utility:pause' : 'utility:play',
            playPauseLabel:
                task.Status === STATUS_IN_PROGRESS ? 'Mark Deferred' : 'Mark In Progress',

            // The status this task will move to if the play/pause button is clicked
            playPauseTargetStatus:
                task.Status === STATUS_IN_PROGRESS ? STATUS_DEFERRED : STATUS_IN_PROGRESS
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
        } else if (status === STATUS_DEFERRED) {
            cssClass += ' task-paused';
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

    // Opens the edit modal for this task, instead of toggling inline buttons. This just shows the spinner overlay on top of it until handleFormLoad() decides the fields are ready to reveal.
    handleEditClick(event) {
        const taskId = event.currentTarget.dataset.id;
        const task = this.tasks.find((t) => t.Id === taskId);

        if (!task || task.isProcessing) {
            return;
        }

        this.editingTaskId = taskId;
        this.editingTaskOwnerId = task.OwnerId;
        this.isModalLoading = true;
        this.showEditModal = true;
    }

    // Cancel button / X — closes without saving
    handleModalClose() {
        this.showEditModal = false;
        this.editingTaskId = undefined;
        this.editingTaskOwnerId = undefined;
        this.isModalLoading = false;
    }

    // Fired by lightning-record-edit-form once it has fetched the record and is about to render its lightning-input-field children with real data. This is the actual "ready" signal — unlike a separate getRecord wire.
    // The double rAF gives the browser one full layout/paint cycle to settle after the fields commit their values, so the spinner overlay lifts only once everything underneath is visually stable.
    handleFormLoad() {
        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                this.isModalLoading = false;
            });
        });
    }

    // Fired by lightning-record-edit-form after a successful save
    handleEditSuccess() {
        this.showEditModal = false;
        this.editingTaskId = undefined;
        this.editingTaskOwnerId = undefined;
        this.isModalLoading = false;

        refreshApex(this.wiredTasksResult).then(() => {
            this.showToast('Success', 'Task updated.', 'success');
        });
    }

    // Fired when the user picks a different user in the Assigned To lookup
    handleOwnerChange(event) {
        this.editingTaskOwnerId = event.detail.recordId;
    }

    // The Save button no longer submits the form natively (type="submit"),
    // because OwnerId isn't one of the lightning-input-field values the
    // form would collect on its own. Instead we call the form's submit()
    // method directly, passing OwnerId in alongside whatever the form
    // collects from its own fields — submit() merges the two.
    handleSaveClick() {
        const form = this.template.querySelector('lightning-record-edit-form');
        if (form) {
            form.submit({ OwnerId: this.editingTaskOwnerId });
        }
    }

    handleComplete(event) {
        this.changeStatus(event.currentTarget.dataset.id, STATUS_COMPLETED);
    }

    handlePlayPause(event) {
        const taskId = event.currentTarget.dataset.id;
        const targetStatus = event.currentTarget.dataset.status;
        this.changeStatus(taskId, targetStatus);
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
                // On success the wire re-fires and decorateTask() rebuilds every row (including resetting isProcessing to false) based on the new Status, which is what flips the icon/buttons/color.
                this.showToast('Success', 'Task updated.', 'success');
            })
            .catch((error) => {
                this.showToast('Error updating task', this.reduceError(error), 'error');
                // The wire won't re-fire on a failed update, so we have to manually clear the spinner/disabled state ourselves here.
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