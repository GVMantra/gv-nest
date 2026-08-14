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

    // Controls whether Upload is displayed
    showUploadButton = true;

    // Stores wired result for refreshApex
    wiredOpportunityDocumentsResult;

    // Detect whether component is running inside Experience Cloud
    connectedCallback() {

        const currentPath = window.location.pathname;

        // Experience Cloud pages contain /s/
        const isExperienceCloud = currentPath.includes('/s/');

        // Salesforce internal = Upload visible
        // Experience Cloud = Upload hidden
        this.showUploadButton = !isExperienceCloud;

        console.log(
            'Experience Cloud:',
            isExperienceCloud
        );

        console.log(
            'Show Upload Button:',
            this.showUploadButton
        );
    }

    // Fetch all active document types
    @wire(getDocumentTypes)
    wiredDocumentTypes({ data, error }) {

        if (data) {

            this.documentTypes = data;
            this.prepareDisplayDocuments();

        } else if (error) {

            console.error(
                'Document Types Error:',
                JSON.stringify(error)
            );
        }
    }

    // Fetch uploaded documents for the current Opportunity
    @wire(getOpportunityDocuments, { opportunityId: '$recordId' })
    wiredOpportunityDocuments(result) {

        this.wiredOpportunityDocumentsResult = result;

        const { data, error } = result;

        if (data) {

            this.uploadedDocuments = data;

            console.log(
                'Uploaded Documents:',
                JSON.stringify(data)
            );

            this.prepareDisplayDocuments();

        } else if (error) {

            console.error(
                'Opportunity Documents Error:',
                JSON.stringify(error)
            );
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
                .filter(
                    item =>
                        item.Document_Type__c === doc.Document_Type__c
                )
                .sort(
                    (a, b) =>
                        new Date(b.Uploaded_On__c) -
                        new Date(a.Uploaded_On__c)
                )[0];

            // Get ContentDocumentId from ContentDocumentLink
            const downloadId =
                uploaded &&
                uploaded.ContentDocumentLinks &&
                uploaded.ContentDocumentLinks.length > 0
                    ? uploaded.ContentDocumentLinks[0].ContentDocumentId
                    : null;

            console.log(
                'Document:',
                doc.Document_Type__c,
                'ContentDocumentId:',
                downloadId
            );

            return {

                id: doc.Id,

                documentType: doc.Document_Type__c,

                mandatory: doc.Mandatory__c,

                status: uploaded
                    ? 'Uploaded'
                    : 'Pending',

                uploadedOn: uploaded
                    ? uploaded.Uploaded_On__c
                    : '',

                uploadedBy:
                    uploaded &&
                    uploaded.Uploaded_By__r
                        ? uploaded.Uploaded_By__r.Name
                        : '',

                // Salesforce ContentDocumentId
                downloadId: downloadId,

                // True when a Salesforce File exists
                hasFile: !!downloadId
            };
        });
    }

    // Opens the upload modal for the selected document type
    handleUploadClick(event) {

        this.selectedDocumentType =
            event.currentTarget.dataset.document;

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

                console.log(
                    'Uploaded ContentDocumentId:',
                    file.documentId
                );

                // Create Opportunity Document record
                const opportunityDocumentId =
                    await createOpportunityDocument({
                        opportunityId: this.recordId,
                        documentType: this.selectedDocumentType
                    });

                console.log(
                    'Opportunity Document Id:',
                    opportunityDocumentId
                );

                // Link uploaded Salesforce File
                await linkFileToOpportunityDocument({
                    contentDocumentId: file.documentId,
                    opportunityDocumentId:
                        opportunityDocumentId
                });
            }

            // Close upload modal
            this.showUploadModal = false;

            // Wait for records to commit
            await new Promise(
                resolve => setTimeout(resolve, 1000)
            );

            // Refresh uploaded document data
            await refreshApex(
                this.wiredOpportunityDocumentsResult
            );

        } catch (error) {

            console.error(
                'Upload Error:',
                JSON.stringify(error)
            );
        }
    }

    // Downloads the uploaded Salesforce File
    handleDownload(event) {

        const documentId =
            event.currentTarget.dataset.id;

        if (!documentId) {

            console.error(
                'ContentDocumentId is missing'
            );

            return;
        }

        // Current page path
        const currentPath =
            window.location.pathname;

        // Determine Experience Cloud site path
        let sitePath = '';

        const siteMarker = '/s/';
        const siteIndex =
            currentPath.indexOf(siteMarker);

        if (siteIndex !== -1) {

            sitePath =
                currentPath.substring(0, siteIndex);
        }

        // Build Salesforce File download URL
        const downloadUrl =
            window.location.origin +
            sitePath +
            '/sfc/servlet.shepherd/document/download/' +
            documentId +
            '?operationContext=S1';

        console.log(
            'ContentDocumentId:',
            documentId
        );

        console.log(
            'Download URL:',
            downloadUrl
        );

        window.open(
            downloadUrl,
            '_blank'
        );
    }
}