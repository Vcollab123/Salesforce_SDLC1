// JiraRequirementController.cls
public with sharing class JiraRequirementController {
    @AuraEnabled(cacheable=true)
    public static Jira_Requirement__c getRequirement(Id recordId) {
        return [
            SELECT Id, Jira_ID__c, Name, Summary__c, Description__c, Acceptance_Criteria__c,
                   Technical_Design__c, Design_Status__c, GitHub_File_URL__c,
                   BA_Prompt__c, BA_Prompt_Respone__c, Technical_Architect_Prompts_Response__c
            FROM Jira_Requirement__c
            WHERE Id = :recordId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static String generateDesign(Id recordId) {
        // wrapper to call OpenAIService.generateDesignFromOpenAI
        return OpenAIService.generateDesignFromOpenAI(recordId);
    }

    @AuraEnabled
    public static Jira_Requirement__c saveBAPrompt(Id recordId, String baPrompt) {
        Jira_Requirement__c r = new Jira_Requirement__c(Id = recordId);
        r.BA_Prompt__c = baPrompt;
        update r;
        return getRequirement(recordId);
    }

    @AuraEnabled
    public static String askClarifyingQuestion(Id recordId, String question) {
        return OpenAIService.askClarifyingQuestion(recordId, question);
    }

    @AuraEnabled
    public static String pushToGitHubRecord(Id recordId) {
        Jira_Requirement__c r = [
            SELECT Id, Jira_ID__c, Technical_Design__c
            FROM Jira_Requirement__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        if (String.isBlank(r.Technical_Design__c)) {
            throw new AuraHandledException('Technical design is empty.');
        }

        String url = GitHubService.pushDesignToGitHub(r.Jira_ID__c == null ? r.Id + '' : r.Jira_ID__c, r.Technical_Design__c);
        r.GitHub_File_URL__c = url;
        update r;
        return url;
    }
}
