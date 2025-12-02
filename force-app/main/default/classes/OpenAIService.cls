// OpenAIService.cls
public with sharing class OpenAIService {
    public class OpenAIException extends Exception {}

    @AuraEnabled
    public static String generateDesignFromOpenAI(Id jiraReqId) {
        Jira_Requirement__c req = [
            SELECT Id, Jira_ID__c, Name, Summary__c, Description__c, Acceptance_Criteria__c
            FROM Jira_Requirement__c
            WHERE Id = :jiraReqId
            LIMIT 1
        ];

        String prompt = buildPrompt(req);

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://api.openai.com/v1/chat/completions');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');

        String apiKey = System.Label.OpenAI_API_KEY;
        if (String.isBlank(apiKey)) throw new OpenAIException('OpenAI API key missing. Create Custom Label OpenAI_API_KEY.');

        request.setHeader('Authorization', 'Bearer ' + apiKey);

        Map<String,Object> systemMsg = new Map<String,Object>{ 'role' => 'system', 'content' => 'You are a senior Salesforce architect. Return one markdown document with sections: Summary, Data Model, Apex Classes, LWC Components, Integration Contracts, Deployment Items, Test Strategy. Return only markdown.' };
        Map<String,Object> userMsg = new Map<String,Object>{ 'role' => 'user', 'content' => prompt };
        List<Object> messages = new List<Object>{ systemMsg, userMsg };

        Map<String,Object> body = new Map<String,Object>{
            'model' => 'gpt-4o-mini',
            'messages' => messages,
            'temperature' => 0.2,
            'max_tokens' => 2000
        };

        request.setBody(JSON.serialize(body));

        HttpResponse resp;
        try {
            resp = http.send(request);
        } catch (System.CalloutException ex) {
            throw new OpenAIException('Callout error: ' + ex.getMessage());
        }

        if (resp.getStatusCode() < 200 || resp.getStatusCode() > 299) {
            throw new OpenAIException('OpenAI error: ' + resp.getStatusCode() + ' - ' + resp.getBody());
        }

        Map<String,Object> parsed = (Map<String,Object>) JSON.deserializeUntyped(resp.getBody());
        String content = '';
        if (parsed.containsKey('choices')) {
            List<Object> choices = (List<Object>) parsed.get('choices');
            if (!choices.isEmpty()) {
                Map<String,Object> first = (Map<String,Object>) choices.get(0);
                if (first.containsKey('message')) {
                    Map<String,Object> message = (Map<String,Object>) first.get('message');
                    content = (String) message.get('content');
                } else if (first.containsKey('text')) {
                    content = (String) first.get('text');
                }
            }
        }

        if (content == null) content = '';

        req.Technical_Design__c = content;
        req.Design_Status__c = 'Design_Generated';
        update req;

        return content;
    }

    @AuraEnabled
    public static String askClarifyingQuestion(Id jiraReqId, String question) {
        Jira_Requirement__c req = [
            SELECT Id, Jira_ID__c, Name, Summary__c, Description__c, Technical_Design__c,
                   BA_Prompt_Respone__c, Technical_Architect_Prompts_Response__c
            FROM Jira_Requirement__c
            WHERE Id = :jiraReqId
            LIMIT 1
        ];

        String systemPrompt = 'You are a senior Salesforce architect. Answer concisely and give actionable guidance.';
        String userPrompt = 'Jira ID: ' + (req.Jira_ID__c == null ? req.Id : req.Jira_ID__c) + '\n\n'
            + 'Summary:\n' + (req.Summary__c == null ? '' : req.Summary__c) + '\n\n'
            + 'Description:\n' + (req.Description__c == null ? '' : req.Description__c) + '\n\n'
            + 'Existing Design (if any):\n' + (req.Technical_Design__c == null ? '[none]' : req.Technical_Design__c) + '\n\n'
            + 'Clarifying question: ' + question + '\n\n'
            + 'Answer with practical steps, field lists, or code skeletons where applicable.';

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://api.openai.com/v1/chat/completions');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');

        String apiKey = System.Label.OpenAI_API_KEY;
        if (String.isBlank(apiKey)) throw new OpenAIException('OpenAI API key missing. Create Custom Label OpenAI_API_KEY.');
        request.setHeader('Authorization', 'Bearer ' + apiKey);

        Map<String,Object> systemMsg = new Map<String,Object>{ 'role' => 'system', 'content' => systemPrompt };
        Map<String,Object> userMsg = new Map<String,Object>{ 'role' => 'user', 'content' => userPrompt };
        List<Object> messages = new List<Object>{ systemMsg, userMsg };

        Map<String,Object> body = new Map<String,Object>{
            'model' => 'gpt-4o-mini',
            'messages' => messages,
            'temperature' => 0.0,
            'max_tokens' => 600
        };

        request.setBody(JSON.serialize(body));
        HttpResponse resp;
        try {
            resp = http.send(request);
        } catch (System.CalloutException ex) {
            throw new OpenAIException('Callout error: ' + ex.getMessage());
        }

        if (resp.getStatusCode() < 200 || resp.getStatusCode() > 299) {
            throw new OpenAIException('OpenAI error: ' + resp.getStatusCode() + ' - ' + resp.getBody());
        }

        Map<String,Object> parsed = (Map<String,Object>) JSON.deserializeUntyped(resp.getBody());
        String content = '';
        if (parsed.containsKey('choices')) {
            List<Object> choices = (List<Object>) parsed.get('choices');
            if (!choices.isEmpty()) {
                Map<String,Object> first = (Map<String,Object>) choices.get(0);
                if (first.containsKey('message')) {
                    Map<String,Object> message = (Map<String,Object>) first.get('message');
                    content = (String) message.get('content');
                } else if (first.containsKey('text')) {
                    content = (String) first.get('text');
                }
            }
        }
        if (content == null) content = '';

        // Append responses to both BA and Architect response fields
        String ts = Datetime.now().format('yyyy-MM-dd HH:mm:ss');
        String appended = '\n\n---\nQuestion: ' + question + '\nAnswer (' + ts + '):\n' + content;

        Jira_Requirement__c upd = new Jira_Requirement__c(Id = req.Id);
        upd.BA_Prompt_Respone__c = (req.BA_Prompt_Respone__c == null ? '' : req.BA_Prompt_Respone__c) + appended;
        upd.Technical_Architect_Prompts_Response__c = (req.Technical_Architect_Prompts_Response__c == null ? '' : req.Technical_Architect_Prompts_Response__c) + appended;
        update upd;

        // optionally create Design_Question__c if available (non-fatal)
        try {
            if (Schema.sObjectType.Design_Question__c.isCreateable()) {
                Design_Question__c dq = new Design_Question__c();
                dq.Jira_Requirement__c = req.Id;
                dq.Question__c = question;
                dq.Answer__c = content;
                insert dq;
            }
        } catch (Exception e) {
            // ignore
        }

        return content;
    }

    private static String buildPrompt(Jira_Requirement__c r) {
        String s = '';
        s += 'Jira ID: ' + (r.Jira_ID__c == null ? r.Id : r.Jira_ID__c) + '\n\n';
        s += 'Summary:\n' + (r.Summary__c == null ? '' : r.Summary__c) + '\n\n';
        s += 'Description:\n' + (r.Description__c == null ? '' : r.Description__c) + '\n\n';
        s += 'Acceptance Criteria:\n' + (r.Acceptance_Criteria__c == null ? '' : r.Acceptance_Criteria__c) + '\n\n';
        s += 'Return a single markdown document with sections: Summary, Data Model, Apex Classes (skeletons), LWC Components (files), Integration Contracts, Deployment Items, Test Strategy.';
        return s;
    }
}
