import { LightningElement, api, track } from 'lwc';
import getRequirement from '@salesforce/apex/JiraRequirementController.getRequirement';
import generateDraftSolution from '@salesforce/apex/JiraRequirementController.generateDraftSolution'; // Import new method
import askClarifyingQuestion from '@salesforce/apex/OpenAIService.askClarifyingQuestion';
import approveDesign from '@salesforce/apex/JiraRequirementController.approveDesign';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';

export default class ArchitectWorkbench extends LightningElement {
    @api recordId;
    @track record;
    @track taPrompt = '';
    @track aiResponse = ''; 
    @track loading = false;
    @track error;
    @track showFullDescription = false;

    connectedCallback() { this.loadRecord(); }

    get isLocked() { return !this.record || this.record.BA_Status__c !== 'Approved'; }
    get descriptionToggleLabel() { return this.showFullDescription ? 'Less' : 'More'; }

    loadRecord() {
        this.loading = true;
        getRequirement({ recordId: this.recordId })
            .then(res => {
                this.record = res;
                this.taPrompt = '';
                
                // CHECK: Is there an existing solution?
                if (res.Technical_Solution__c) {
                    this.aiResponse = res.Technical_Solution__c;
                    this.loading = false;
                } else {
                    // IF EMPTY: Automatically generate the default solution
                    if (res.BA_Status__c === 'Approved') {
                        this.generateDefault();
                    } else {
                        this.loading = false;
                    }
                }
            })
            .catch(err => {
                this.loading = false;
                this.error = JSON.stringify(err);
            });
    }

    // New function to auto-generate content
    async generateDefault() {
        try {
            // Show a toast so the user knows AI is working
            this.dispatchEvent(new ShowToastEvent({ title: 'AI Working', message: 'Generating default technical solution...', variant: 'info' }));
            
            const draft = await generateDraftSolution({ recordId: this.recordId });
            this.aiResponse = draft || '';
        } catch (err) {
            console.error(err);
        } finally {
            this.loading = false;
        }
    }

    toggleDescription() { this.showFullDescription = !this.showFullDescription; }
    handlePromptChange(evt) { this.taPrompt = evt.target.value; }
    handleResponseChange(evt) { this.aiResponse = evt.target.value; }

    async handleAskAI() {
        if (!this.taPrompt) return;
        this.loading = true;
        try {
            const answer = await askClarifyingQuestion({ jiraReqId: this.recordId, question: this.taPrompt });
            this.aiResponse = answer || '';
        } catch (err) {
            this.error = JSON.stringify(err);
        } finally {
            this.loading = false;
        }
    }

    async handleApprove() {
        if (!this.aiResponse) return;
        if (!confirm('Approve Technical Solution?')) return;
        this.loading = true;
        try {
            const res = await approveDesign({ recordId: this.recordId, prompt: this.taPrompt, response: this.aiResponse });
            this.record = res;
            getRecordNotifyChange([{recordId: this.recordId}]);
            this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Technical Solution Approved.', variant: 'success' }));
        } catch (err) {
            this.error = JSON.stringify(err);
        } finally {
            this.loading = false;
        }
    }
}