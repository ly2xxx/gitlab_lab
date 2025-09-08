/**
 * Advanced Renovate Configuration (JavaScript)
 * 
 * This file demonstrates advanced configuration patterns using JavaScript
 * for dynamic configuration, environment-based settings, and complex logic.
 * 
 * Use this instead of renovate.json when you need:
 * - Environment-based configuration
 * - Dynamic repository discovery
 * - Complex conditional logic
 * - Integration with external systems
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Environment detection
const isProduction = process.env.NODE_ENV === 'production';
const isGitLabCI = process.env.GITLAB_CI === 'true';
const gitlabUrl = process.env.CI_API_V4_URL?.replace('/api/v4', '') || 'http://host.docker.internal';
const gitlabToken = process.env.RENOVATE_TOKEN;

// Dynamic configuration based on environment
const baseConfig = {
  $schema: 'https://docs.renovatebot.com/renovate-schema.json',
  description: 'Dynamic GitLab Renovate Runner Configuration',
  
  // Platform configuration (endpoint and token managed via environment)
  endpoint: process.env.RENOVATE_ENDPOINT || `${gitlabUrl}/api/v4/`,
  token: gitlabToken,
  
  // Git configuration
  gitAuthor: process.env.RENOVATE_GIT_AUTHOR || 'Renovate Bot <renovate@example.com>',
  
  // Base extends - environment dependent
  extends: [
    'config:recommended',
    ...(isProduction ? ['config:best-practices'] : []),
    ':dependencyDashboard',
    ':semanticCommits',
    ':separateMajorReleases',
    'group:monorepos',
    'group:recommended'
  ].filter(Boolean),
  
  // Performance settings
  repositoryCache: 'enabled',
  optimizeForDisabled: true,
  
  // Concurrent limits based on environment
  prConcurrentLimit: isProduction ? 20 : 5,
  branchConcurrentLimit: isProduction ? 20 : 5,
  prHourlyLimit: isProduction ? 4 : 2,
  
  // Logging configuration (managed via environment variables)
  
  // Timezone and scheduling
  timezone: process.env.TZ || 'UTC',
  schedule: getScheduleByEnvironment(),
  
  // Labels and assignment
  labels: getLabelsForEnvironment(),
  assignees: getAssigneesForEnvironment(),
  reviewers: getReviewersForEnvironment(),
  
  // Security settings
  vulnerabilityAlerts: {
    enabled: true,
    schedule: ['at any time'],
    labels: ['security', 'vulnerability'],
    assignees: getSecurityTeam(),
    reviewers: getSecurityTeam()
  },
  osvVulnerabilityAlerts: true,
  
  // Branch and commit configuration
  branchPrefix: process.env.RENOVATE_BRANCH_PREFIX || 'renovate/',
  commitMessagePrefix: 'chore(deps):',
  semanticCommits: 'enabled',
  
  // Merge configuration
  platformAutomerge: isProduction,
  rebaseWhen: 'behind-base-branch',
  
  // Package rules - dynamic based on detected technologies
  packageRules: generatePackageRules(),
  
  // Custom managers for various file types
  regexManagers: [
    // Docker images in compose files
    {
      fileMatch: ['(^|/)docker-compose\\.ya?ml$'],
      matchStrings: [
        'image:\\s*(?<depName>[^:]+):(?<currentValue>[^\\s]+)'
      ],
      datasourceTemplate: 'docker'
    },
    
    // Version variables in shell scripts
    {
      fileMatch: ['^scripts/.*\\.sh$', '^bin/.*$'],
      matchStrings: [
        '(?<depName>[A-Z_]+)_VERSION=["\'](?<currentValue>[^"\']+)["\']'
      ],
      datasourceTemplate: 'github-releases',
      depNameTemplate: '{{#if (containsString depName "NODEJS")}}nodejs/node{{else}}{{depName}}{{/if}}'
    },
    
    // GitLab CI includes
    {
      fileMatch: ['^\\.gitlab-ci\\.ya?ml$'],
      matchStrings: [
        'include:\\s*-\\s*project:\\s*["\'](?<depName>[^"\']+)["\']\\s*file:\\s*["\'][^"\']*["\']\\s*ref:\\s*["\'](?<currentValue>[^"\']+)["\']'
      ],
      datasourceTemplate: 'gitlab-tags'
    }
  ],
  
  // Host rules for performance and authentication
  hostRules: generateHostRules(),
  
  // Repository-specific ignore patterns
  ignorePaths: [
    'node_modules/**',
    'vendor/**', 
    '.git/**',
    '**/test/**',
    '**/tests/**',
    'examples/**',
    'docs/**'
  ],
  
  // Lock file maintenance
  lockFileMaintenance: {
    enabled: true,
    schedule: ['before 5am on monday'],
    commitMessageAction: 'Lock file maintenance',
    branchTopic: 'lock-file-maintenance'
  }
};

// Dynamic functions for configuration generation

function getScheduleByEnvironment() {
  if (isProduction) {
    return [
      'after 10pm every weekday',
      'before 5am every weekday',
      'every weekend'
    ];
  } else {
    // More frequent updates in development
    return [
      'after 6pm every weekday',
      'before 8am every weekday', 
      'every weekend'
    ];
  }
}

function getLabelsForEnvironment() {
  const baseLabels = ['renovate', 'dependencies'];
  
  if (isProduction) {
    baseLabels.push('production');
  } else {
    baseLabels.push('development');
  }
  
  if (isGitLabCI) {
    baseLabels.push('automated');
  }
  
  return baseLabels;
}

function getAssigneesForEnvironment() {
  // Could be loaded from environment or external API
  const assignees = process.env.RENOVATE_ASSIGNEES?.split(',') || [];
  return assignees.map(assignee => assignee.trim()).filter(Boolean);
}

function getReviewersForEnvironment() {
  // Could be loaded from environment or external API  
  const reviewers = process.env.RENOVATE_REVIEWERS?.split(',') || [];
  return reviewers.map(reviewer => reviewer.trim()).filter(Boolean);
}

function getSecurityTeam() {
  return process.env.RENOVATE_SECURITY_TEAM?.split(',') || ['@security-team'];
}

function generatePackageRules() {
  const rules = [
    // Base rules for all environments
    {
      description: 'Auto-merge non-major updates',
      matchUpdateTypes: ['minor', 'patch', 'pin', 'digest'],
      automerge: true,
      automergeType: 'pr',
      platformAutomerge: isProduction
    },
    
    {
      description: 'Security updates get immediate attention',
      matchPackagePatterns: ['*security*', '*vulnerability*'],
      groupName: 'Security updates',
      schedule: ['at any time'],
      labels: ['security', 'high-priority'],
      automerge: false,
      assignees: getSecurityTeam(),
      reviewers: getSecurityTeam()
    },
    
    {
      description: 'Major updates require review',
      matchUpdateTypes: ['major'],
      labels: ['major-update', 'needs-review'],
      automerge: false,
      assignees: getAssigneesForEnvironment(),
      reviewers: getReviewersForEnvironment()
    }
  ];
  
  // Add environment-specific rules
  if (isProduction) {
    rules.push({
      description: 'Production: Conservative updates only',
      matchUpdateTypes: ['patch'],
      schedule: ['every weekend'],
      automerge: true
    });
  } else {
    rules.push({
      description: 'Development: Allow more aggressive updates',
      matchUpdateTypes: ['minor', 'patch'],
      schedule: ['after 6pm'],
      automerge: true
    });
  }
  
  // Technology-specific rules based on detection
  const detectedTech = detectProjectTechnology();
  
  if (detectedTech.hasNodeJS) {
    rules.push({
      description: 'Node.js: Group related packages',
      matchPackagePatterns: ['^@types/', 'typescript', 'ts-node'],
      groupName: 'TypeScript and types',
      labels: ['typescript']
    });
  }
  
  if (detectedTech.hasPython) {
    rules.push({
      description: 'Python: Pin versions for stability',
      matchCategories: ['python'],
      rangeStrategy: 'pin',
      labels: ['python']
    });
  }
  
  if (detectedTech.hasDocker) {
    rules.push({
      description: 'Docker: Group base image updates',
      matchDatasources: ['docker'],
      groupName: 'Docker base images',
      schedule: ['every weekend'],
      labels: ['docker'],
      reviewers: getReviewersForEnvironment()
    });
  }
  
  return rules;
}

function generateHostRules() {
  const hostRules = [
    {
      matchHost: 'registry.npmjs.org',
      timeout: 30000
    },
    {
      matchHost: 'pypi.org',
      timeout: 30000  
    }
  ];
  
  // Add private registry rules if configured
  const privateRegistry = process.env.PRIVATE_REGISTRY_URL;
  const privateRegistryToken = process.env.PRIVATE_REGISTRY_TOKEN;
  
  if (privateRegistry && privateRegistryToken) {
    hostRules.push({
      matchHost: privateRegistry,
      token: privateRegistryToken
    });
  }
  
  return hostRules;
}

function detectProjectTechnology() {
  const hasFile = (filename) => fs.existsSync(path.join(process.cwd(), filename));
  
  return {
    hasNodeJS: hasFile('package.json'),
    hasPython: hasFile('requirements.txt') || hasFile('pyproject.toml') || hasFile('Pipfile'),
    hasDocker: hasFile('Dockerfile') || hasFile('docker-compose.yml'),
    hasGo: hasFile('go.mod'),
    hasRust: hasFile('Cargo.toml'),
    hasJava: hasFile('pom.xml') || hasFile('build.gradle'),
    hasRuby: hasFile('Gemfile'),
    hasPHP: hasFile('composer.json')
  };
}

function getDepNameFromEnvVar(envVar) {
  // Map environment variable names to actual package names
  const mapping = {
    'NODEJS_VERSION': 'nodejs/node',
    'DOCKER_VERSION': 'docker/docker',
    'KUBECTL_VERSION': 'kubernetes/kubectl',
    'TERRAFORM_VERSION': 'hashicorp/terraform'
  };
  
  return mapping[envVar] || envVar.toLowerCase().replace('_', '/');
}

// Repository-specific overrides based on project detection
function getRepositoryOverrides() {
  const overrides = [];
  const projectPath = process.env.CI_PROJECT_PATH;
  
  if (projectPath) {
    // Example: Different rules for different project types
    if (projectPath.includes('/frontend/') || projectPath.includes('/ui/')) {
      overrides.push({
        matchFiles: ['package.json'],
        labels: ['frontend'],
        reviewers: ['@frontend-team']
      });
    }
    
    if (projectPath.includes('/backend/') || projectPath.includes('/api/')) {
      overrides.push({
        matchFiles: ['requirements.txt', 'pyproject.toml', 'pom.xml'],
        labels: ['backend'],
        reviewers: ['@backend-team']
      });
    }
    
    if (projectPath.includes('/infrastructure/') || projectPath.includes('/ops/')) {
      overrides.push({
        matchDatasources: ['docker', 'terraform'],
        labels: ['infrastructure'],
        reviewers: ['@devops-team']
      });
    }
  }
  
  return overrides;
}

// Apply repository-specific overrides
baseConfig.packageRules.push(...getRepositoryOverrides());

// Debug logging in non-production
if (!isProduction) {
  console.log('Renovate configuration loaded with the following settings:');
  console.log(`- Environment: ${isProduction ? 'production' : 'development'}`);
  console.log(`- GitLab URL: ${gitlabUrl}`);
  console.log(`- Autodiscover filter: ${process.env.RENOVATE_AUTODISCOVER_FILTER || '*/*'}`);
  console.log(`- Dry run: ${process.env.RENOVATE_DRY_RUN || 'full'}`);
  console.log(`- Package rules: ${baseConfig.packageRules.length}`);
}

module.exports = baseConfig;