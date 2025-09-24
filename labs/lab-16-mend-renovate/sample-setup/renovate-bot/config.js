module.exports = { 
    endpoint: 'http://host.docker.internal:8090/api/v4/', 
    token: process.env.GITLAB_TOKEN, 
    platform: 'gitlab', 
    enabledManagers: ['pip_requirements'],
    prHourlyLimit: 0, 
    rebaseWhen: "behind-base-branch", 
    constraints: { 
        "python": ">=3.8" 
    }, 
    onboardingConfig: { 
        extends: [ 
            "config:base", 
            ":preserveSemverRanges", 
            ":rebaseStalePrs", 
            ":enableVulnerabilityAlertsWithLabel('security')", 
            "group:recommended" 
        ] 
    }, 
    repositories: ['root/lab-09-conditional-pipeline'], 
};
