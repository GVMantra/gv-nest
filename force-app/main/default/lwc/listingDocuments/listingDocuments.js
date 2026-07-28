import { LightningElement, wire, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';

import getDocumentTypes from '@salesforce/apex/ListingDocumentsController.getDocumentTypes';
import getOpportunityDocuments from '@salesforce/apex/ListingDocumentsController.getOpportunityDocuments';
import createOpportunityDocument from '@salesforce/apex/ListingDocumentsController.createOpportunityDocument';
import linkFileToOpportunityDocument from '@salesforce/apex/ListingDocumentsController.linkFileToOpportunityDocument';

export default class ListingDocuments extends LightningElement {

    // Current Opportunity Record Id
    @api recordId;

    // Stores document types, uploaded documents and data displayed in the table
    documentTypes = [];
    uploadedDocuments = [];
    displayDocuments = [];

    // Stores selected document type for upload
    selectedDocumentType;

    // Controls upload modal visibility
    showUploadModal = false;

    // Stores wired result for refreshApex
    wiredOpportunityDocumentsResult;

    // Fetch all active document types
    @wire(getDocumentTypes)
    wiredDocumentTypes({ data, error }) {

        if (data) {

            this.documentTypes = data;
            this.prepareDisplayDocuments();

        } else if (error) {

            console.error(error);

        }
    }

    // Fetch uploaded documents for the current Opportunity
    @wire(getOpportunityDocuments, { opportunityId: '$recordId' })
    wiredOpportunityDocuments(result) {

        this.wiredOpportunityDocumentsResult = result;

        const { data, error } = result;

        if (data) {

            this.uploadedDocuments = data;

            this.prepareDisplayDocuments();

        } else if (error) {

            console.error(error);

        }
    }

    // Prepare document data for displaying in the table
    prepareDisplayDocuments() {

        if (!this.documentTypes.length) {
            return;
        }

        this.displayDocuments = this.documentTypes.map(doc => {

            // Find the latest uploaded document for each document type
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

                // Store ContentDocumentId for download
                downloadId:
                    uploaded &&
                    uploaded.ContentDocumentLinks &&
                    uploaded.ContentDocumentLinks.length
                        ? uploaded.ContentDocumentLinks[0].ContentDocumentId
                        : null,

                // Determines whether a file is available for download
                hasFile:
                    uploaded &&
                    uploaded.ContentDocumentLinks &&
                    uploaded.ContentDocumentLinks.length > 0

            };

        });

    }

    // Opens the upload modal for the selected document type
    handleUploadClick(event) {

        this.selectedDocumentType = event.target.dataset.document;

        this.showUploadModal = true;

    }

    // Closes the upload modal
    handleCancel() {

        this.showUploadModal = false;

    }

    // Creates Opportunity Document record and links uploaded file
    async handleUploadFinished(event) {

        try {

            const uploadedFiles = event.detail.files;

            for (const file of uploadedFiles) {

                // Create Opportunity Document record
                const opportunityDocumentId = await createOpportunityDocument({

                    opportunityId: this.recordId,
                    documentType: this.selectedDocumentType

                });

                // Link uploaded Salesforce File with Opportunity Document
                await linkFileToOpportunityDocument({

                    contentDocumentId: file.documentId,
                    opportunityDocumentId: opportunityDocumentId

                });

            }

            // Close upload modal
            this.showUploadModal = false;

            // Wait briefly to ensure records are committed
            await new Promise(resolve => setTimeout(resolve, 1000));

            // Refresh uploaded document data
            await refreshApex(this.wiredOpportunityDocumentsResult);

        } catch (error) {

            console.error('Upload Error', error);

        }

    }

    // Downloads the uploaded Salesforce File
    handleDownload(event) {

        const documentId = event.target.dataset.id;

        window.open(
            '/sfc/servlet.shepherd/document/download/' + documentId,
            '_blank'
        );

    }

}