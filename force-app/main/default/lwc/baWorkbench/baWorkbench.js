import { LightningElement, api, track } from 'lwc';
import getRequirement from '@salesforce/apex/JiraRequirementController.getRequirement';
import askAI from '@salesforce/apex/JiraRequirementController.askAI';
import approveBAContent from '@salesforce/apex/JiraRequirementController.approveBAContent';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';

export default class BaWorkbench extends LightningElement {
    @api recordId;
    @track record;
    @track baPrompt = '';
    @track aiResponse = ''; 
    @track loading = false;
    @track error;

    connectedCallback() { this.loadRecord(); }

    get statusLabel() { return this.record?.BA_Status__c || 'Draft'; }
    get statusClass() { return this.record?.BA_Status__c === 'Approved' ? 'slds-theme_success' : 'slds-theme_warning'; }

    loadRecord() {
        this.loading = true;
        getRequirement({ recordId: this.recordId })
            .then(res => {
                this.record = res;
                // This loads whatever is currently in the DB
                this.baPrompt = res.BA_Prompt__c || '';
                // Ensure this matches your Apex field name mapping
                this.aiResponse = res.BA_Prompt_Respone__c || ''; 
                this.loading = false;
            })
            .catch(err => {
                this.loading = false;
                this.error = JSON.stringify(err);
            });
    }

    handlePromptChange(evt) { this.baPrompt = evt.target.value; }
    handleAiResponseChange(evt) { this.aiResponse = evt.target.value; }

    async handleAskAI() {
        if (!this.baPrompt) return;
        this.loading = true;
        try {
            const answer = await askAI({ recordId: this.recordId, prompt: this.baPrompt });
            this.aiResponse = answer || '';
        } catch (err) {
            this.showError(err);
        } finally {
            this.loading = false;
        }
    }

    async handleApprove() {
        // DEBUG: Check if we have data before sending
        console.log('Attempting Approval...');
        console.log('Response Content:', this.aiResponse);

        if (!this.aiResponse) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Response is empty', variant: 'error' }));
            return;
        }

        this.loading = true;
        try {
            // DEBUG: Calling Apex
            const res = await approveBAContent({
                recordId: this.recordId, 
                useAsSame: false, 
                manualContent: this.aiResponse, 
                baPrompt: this.baPrompt
            });
            
            console.log('Apex Success:', res);
            this.record = res;
            getRecordNotifyChange([{recordId: this.recordId}]);
            this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Approved & Unlocked TA', variant: 'success' }));
        
        } catch (err) {
            console.error('Apex Failure:', err);
            this.showError(err); // This will show the real error on screen
        } finally {
            this.loading = false;
        }
    }
    
    // Helper to extract clean error message
    showError(err) {
        let msg = 'Unknown Error';
        if (err.body && err.body.message) msg = err.body.message;
        else if (err.message) msg = err.message;
        else msg = JSON.stringify(err);
        
        this.error = msg;
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' }));
    }
}