import { LightningElement, wire, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';

import getDocumentTypes from '@salesforce/apex/ListingDocumentsController.getDocumentTypes';
import getOpportunityDocuments from '@salesforce/apex/ListingDocumentsController.getOpportunityDocuments';
import createOpportunityDocument from '@salesforce/apex/ListingDocumentsController.createOpportunityDocument';
import linkFileToOpportunityDocument from '@salesforce/apex/ListingDocumentsController.linkFileToOpportunityDocument';

export default class ListingDocuments extends LightningElement {

    @api recordId;

    documentTypes = [];
    uploadedDocuments = [];
    displayDocuments = [];

    selectedDocumentType;
    showUploadModal = false;

    wiredOpportunityDocumentsResult;

    @wire(getDocumentTypes)
    wiredDocumentTypes({ data, error }) {

        if (data) {
            this.documentTypes = data;
            this.prepareDisplayDocuments();
        } else if (error) {
            console.error(error);
        }
    }

    @wire(getOpportunityDocuments, { opportunityId: '$recordId' })
    wiredOpportunityDocuments(result) {

        this.wiredOpportunityDocumentsResult = result;

        const { data, error } = result;

        if (data) {

            console.log('Wire Fired');
            console.log(data);

            this.uploadedDocuments = data;

            this.prepareDisplayDocuments();

        } else if (error) {

            console.error(error);

        }
    }

    prepareDisplayDocuments() {

        if (!this.documentTypes.length) {
            return;
        }

        this.displayDocuments = this.documentTypes.map(doc => {

            const uploaded = this.uploadedDocuments
                .filter(item => item.Document_Type__c === doc.Document_Type__c)
                .sort((a, b) => new Date(b.Uploaded_On__c) - new Date(a.Uploaded_On__c))[0];

            return {

                id: doc.Id,

                documentType: doc.Document_Type__c,

                mandatory: doc.Mandatory__c,

                status: uploaded ? 'Uploaded' : 'Pending',

                uploadedOn: uploaded ? uploaded.Uploaded_On__c : '',

                uploadedBy:
                    uploaded && uploaded.Uploaded_By__r
                        ? uploaded.Uploaded_By__r.Name
                        : '',

                downloadId:
                    uploaded &&
                    uploaded.ContentDocumentLinks &&
                    uploaded.ContentDocumentLinks.length
                        ? uploaded.ContentDocumentLinks[0].ContentDocumentId
                        : null,

                hasFile:
                    uploaded &&
                    uploaded.ContentDocumentLinks &&
                    uploaded.ContentDocumentLinks.length > 0

            };

        });

    }

    handleUploadClick(event) {

        this.selectedDocumentType = event.target.dataset.document;

        this.showUploadModal = true;

    }

    handleCancel() {

        this.showUploadModal = false;

    }

    async handleUploadFinished(event) {

        try {

            const uploadedFiles = event.detail.files;

            for (const file of uploadedFiles) {

                console.log('Uploading:', file.name);

                const opportunityDocumentId = await createOpportunityDocument({

                    opportunityId: this.recordId,
                    documentType: this.selectedDocumentType

                });

                await linkFileToOpportunityDocument({

                    contentDocumentId: file.documentId,
                    opportunityDocumentId: opportunityDocumentId

                });

            }

            this.showUploadModal = false;

            // Wait briefly so Salesforce commits the records
            await new Promise(resolve => setTimeout(resolve, 1000));

            // Refresh the wired Apex data
            await refreshApex(this.wiredOpportunityDocumentsResult);

            console.log('Component Refreshed');

        } catch (error) {

            console.error('Upload Error', error);

        }

    }

    handleDownload(event) {

        const documentId = event.target.dataset.id;

        window.open(
            '/sfc/servlet.shepherd/document/download/' + documentId,
            '_blank'
        );

    }

}