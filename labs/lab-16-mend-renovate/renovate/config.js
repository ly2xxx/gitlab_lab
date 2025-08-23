/**
 * Renovate CLI Configuration
 * 
 * This file provides custom configuration for the Renovate CLI that complements
 * the environment variables. It's mounted to /usr/src/app/config.js in the container.
 * 
 * Documentation: https://docs.renovatebot.com/configuration-options/
 */

module.exports = {
  // Platform configuration
  platform: 'gitlab',
  gitlabUrl: process.env.MEND_RNV_ENDPOINT?.replace('/api/v4/', '') || 'http://localhost:8080',
  
  // Authentication
  token: process.env.MEND_RNV_GITLAB_PAT,
  
  // Repository discovery
  autodiscover: true,
  autodiscoverFilter: ['*/*'], // Discover all repositories
  
  // Git configuration
  gitAuthor: 'Renovate Bot <renovate-bot@example.local>',
  
  // Logging
  logLevel: process.env.LOG_LEVEL || 'info',
  
  // Performance tuning
  prConcurrentLimit: parseInt(process.env.RENOVATE_PR_CONCURRENT_LIMIT) || 10,
  branchConcurrentLimit: parseInt(process.env.RENOVATE_BRANCH_CONCURRENT_LIMIT) || 10,
  
  // Repository-specific settings that can be overridden by renovate.json
  extends: [
    'config:recommended',
  ],
  
  // Global package rules (can be overridden per repository)
  packageRules: [
    {
      // Auto-merge devDependencies with patch/minor updates
      matchDepTypes: ['devDependencies'],
      matchUpdateTypes: ['patch', 'minor'],
      automerge: true,
      automergeType: 'pr',
    },
    {
      // Group security updates
      matchDatasources: ['npm'],
      matchPackageNames: ['/security/'],
      groupName: 'Security updates',
      schedule: ['at any time'],
      labels: ['security'],
    },
    {
      // Handle Docker images
      matchDatasources: ['docker'],
      versioning: 'docker',
      schedule: ['before 6am on monday'],
    },
  ],
  
  // Vulnerability alerts
  vulnerabilityAlerts: {
    enabled: true,
    schedule: ['at any time'],
    labels: ['security', 'vulnerability'],
  },
  
  // OSV (Open Source Vulnerabilities) integration
  osvVulnerabilityAlerts: true,
  
  // Custom host rules (for private registries, if needed)
  hostRules: [
    {
      matchHost: 'registry.npmjs.org',
      timeout: 30000,
    },
    // Add custom registry rules here if needed
    // {
    //   matchHost: 'your-private-registry.com',
    //   username: 'your-username',
    //   password: process.env.PRIVATE_REGISTRY_PASSWORD,
    // },
  ],
  
  // Repository templates (default settings for repositories)
  repositories: [], // Discovered automatically
  
  // Onboarding settings
  onboarding: true,
  onboardingConfig: {
    extends: ['config:recommended'],
  },
  
  // HTTP settings
  httpTimeout: parseInt(process.env.RENOVATE_HTTP_TIMEOUT) || 60000,
  
  // Cache settings
  repositoryCacheType: 'enabled',
  
  // Timezone
  timezone: 'UTC',
  
  // Additional settings for GitLab
  includeForks: false,
  forkProcessing: 'disabled',
  
  // Merge request settings
  platform: 'gitlab',
  gitlabAutomerge: true,
  
  // Custom managers (if needed)
  customManagers: [
    // Example: Custom manager for Docker Compose files
    {
      customType: 'regex',
      fileMatch: ['(^|/)docker-compose\\.ya?ml$'],
      matchStrings: [
        'image:\\s*(?<depName>[^:]+):(?<currentValue>[^\\s]+)',
      ],
      datasourceTemplate: 'docker',
    },
  ],
  
  // Labels for all PRs created by Renovate
  labels: ['renovate', 'dependencies'],
  
  // Assignees and reviewers (can be overridden per repository)
  assignees: [], // Set in repository-specific config
  reviewers: [], // Set in repository-specific config
  
  // Branch prefix
  branchPrefix: 'renovate/',
  
  // Commit message settings
  semanticCommits: 'enabled',
  commitMessagePrefix: 'chore(deps):',
  
  // Lockfile maintenance
  lockFileMaintenance: {
    enabled: true,
    schedule: ['before 5am on monday'],
    commitMessageAction: 'Lock file maintenance',
  },
  
  // Dependency dashboard
  dependencyDashboard: true,
  dependencyDashboardTitle: 'Dependency Dashboard',
  
  // Schedule (can be overridden per repository)
  schedule: ['after 10pm every weekday', 'before 5am every weekday', 'every weekend'],
};
