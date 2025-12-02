// GitHubService.cls
public with sharing class GitHubService {
    @AuraEnabled
    public static String pushDesignToGitHub(String jiraId, String markdownContent) {
        if (String.isBlank(jiraId)) jiraId = Datetime.now().getTime() + '';
        String filePath = 'designs/' + jiraId + '.md';
        String base64Content = EncodingUtil.base64Encode(Blob.valueOf(markdownContent));

        HttpRequest req = new HttpRequest();
        // ensure you created a Named Credential called GitHub_NC that points to https://api.github.com
        req.setEndpoint('callout:GitHub_NC/repos/Vcollab123/Salesforce_SDLC/contents/' + EncodingUtil.urlEncode(filePath, 'UTF-8'));
        req.setMethod('PUT');
        req.setHeader('Content-Type', 'application/json');

        Map<String,Object> body = new Map<String,Object>{
            'message' => 'Add/Update technical design for ' + jiraId,
            'content' => base64Content
        };

        req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse resp = http.send(req);

        if (resp.getStatusCode() != 201 && resp.getStatusCode() != 200) {
            throw new AuraHandledException('GitHub push failed: ' + resp.getBody());
        }

        Map<String,Object> parsed = (Map<String,Object>) JSON.deserializeUntyped(resp.getBody());
        Map<String,Object> content = (Map<String,Object>) parsed.get('content');
        String downloadUrl = '';
        if (content != null && content.containsKey('download_url')) {
            downloadUrl = (String) content.get('download_url');
        }
        return downloadUrl;
    }
}
