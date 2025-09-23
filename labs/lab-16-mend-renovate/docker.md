# Docker Image Version Upgrade Process

This document analyzes how Renovate handles Docker image version upgrades, detailing the complete process flow, files involved, and configuration options.

## Overview

Renovate's Docker upgrade functionality consists of two main components:
1. **Docker Manager** (`lib/modules/manager/dockerfile/`) - Extracts Docker image dependencies from Dockerfiles
2. **Docker Datasource** (`lib/modules/datasource/docker/`) - Retrieves available versions from Docker registries

## Complete Upgrade Process Flow

### 1. Repository Initialization
```
lib/renovate.ts → lib/workers/global/index.ts → lib/workers/repository/index.ts
```

### 2. Dependency Extraction Phase
```
extract.ts → manager/dockerfile/extract.ts → getDep() → splitImageParts()
```
- Parses Dockerfile instructions (FROM, COPY --from, RUN --mount)
- Extracts image names, tags, and digests
- Handles multi-stage builds and variables
- Supports registry aliases and special prefixes

### 3. Version Lookup Phase
```
fetch.ts → lookup/index.ts → datasource/docker/index.ts → getReleases()
```
- Connects to Docker registries with authentication
- Fetches available tags using Registry v2 API or platform-specific APIs
- Handles pagination and rate limiting
- Retrieves image metadata and labels

### 4. Update Generation Phase
```
lookup/generate.ts → calculateNewValue() → applyPackageRules()
```
- Compares current vs available versions
- Applies versioning strategies (Docker, semver, etc.)
- Generates update candidates with digest support
- Handles pinning strategies

### 5. Branch Creation & PR Generation
```
workers/repository/process/write.ts → git operations → platform PR creation
```

## Files Involved (Hierarchical Structure)

### Core Entry Points
```
lib/
├── renovate.ts                           # Main entry point
├── workers/
│   ├── global/index.ts                   # Global orchestration
│   └── repository/
│       ├── index.ts                      # Repository processing
│       └── process/
│           ├── extract-update.ts         # Extraction coordinator
│           ├── fetch.ts                  # Dependency lookup
│           └── lookup/
│               ├── index.ts              # Version lookup logic
│               ├── generate.ts           # Update generation
│               └── types.ts              # Type definitions
```

### Docker Manager Module
```
lib/modules/manager/dockerfile/
├── index.ts                              # Manager configuration
├── extract.ts                           # Dockerfile parsing
├── extract.spec.ts                      # Tests
├── readme.md                            # Documentation
└── __fixtures__/                        # Test fixtures
    ├── 1.Dockerfile
    ├── 2.Dockerfile
    ├── 3.Dockerfile
    └── 4.Dockerfile
```

### Docker Datasource Module
```
lib/modules/datasource/docker/
├── index.ts                             # Main datasource implementation
├── common.ts                            # Shared utilities
├── dockerhub-cache.ts                   # Docker Hub caching
├── ecr.ts                               # AWS ECR support
├── google.ts                            # Google Container Registry
├── schema.ts                            # JSON schemas
├── types.ts                             # Type definitions
├── *.spec.ts                            # Test files
└── readme.md                            # Documentation
```

### Docker Versioning
```
lib/modules/versioning/docker/
├── index.ts                             # Docker versioning logic
├── index.spec.ts                        # Tests
└── readme.md                            # Documentation
```

### Configuration System
```
lib/config/
├── options/index.ts                     # Configuration options
├── types.ts                             # Type definitions
└── validation.ts                        # Validation logic
```

### Support Files
```
lib/util/
├── http/                                # HTTP client and caching
├── git/                                 # Git operations
├── exec/docker.ts                       # Docker container management
└── string-match.ts                      # String matching utilities
```

## Key Algorithms and Logic

### 1. Image Parsing (`extract.ts:splitImageParts`)
```typescript
// Handles formats: registry/namespace/image:tag@digest
// Supports variables: ${REGISTRY:-default}/image:${TAG:-latest}
// Special cases: library/ prefix, architecture prefixes (amd64/, arm64/)
```

### 2. Registry Authentication (`common.ts:getAuthHeaders`)
```typescript
// Supports multiple auth methods:
// - Basic auth with username/password
// - Bearer tokens
// - AWS ECR tokens
// - Google Cloud tokens
// - Registry-specific auth flows
```

### 3. Tag Fetching (`index.ts:getTags`)
```typescript
// Registry API strategies:
// - Docker Registry v2 API (/v2/{name}/tags/list)
// - Quay.io REST API (v1 fallback)
// - Docker Hub API with enhanced metadata
// - Pagination handling for large repositories
```

### 4. Digest Resolution (`index.ts:getDigest`)
```typescript
// Multi-architecture support:
// - Manifest list handling
// - Architecture-specific digest selection
// - Fallback to content-digest headers
```

## Configuration Options

### Global Docker Settings
```typescript
// lib/config/options/index.ts
{
  dockerChildPrefix: string;        // Container name prefix
  dockerCliOptions: string;         // Docker CLI flags
  dockerSidecarImage: string;       // Sidecar image override
  dockerUser: string;               // UID/GID for containers
  dockerMaxPages: number;           // Registry pagination limit (default: 20)
}
```

### Docker Manager Configuration
```typescript
// lib/modules/manager/dockerfile/index.ts
{
  managerFilePatterns: [
    '/(^|/|\\.)([Dd]ocker|[Cc]ontainer)file$/',
    '/(^|/)([Dd]ocker|[Cc]ontainer)file[^/]*$/'
  ],
  supportedDatasources: ['docker']
}
```

### Docker Datasource Configuration
```typescript
// lib/modules/datasource/docker/index.ts
{
  defaultRegistryUrls: ['https://index.docker.io'],
  defaultVersioning: 'docker',
  commitMessageTopic: '{{{depName}}} Docker tag',
  digest: {
    branchTopic: '{{{depNameSanitized}}}-{{{currentValue}}}',
    commitMessageTopic: '{{{depName}}}{{#if currentValue}}:{{{currentValue}}}{{/if}} Docker digest'
  }
}
```

### Package Rules for Docker
```typescript
// Configuration options available for package rules
{
  packageNames: string[];           // Specific image names
  packagePatterns: string[];        # Image name patterns
  managers: ['dockerfile'];         # Target Dockerfile manager
  datasources: ['docker'];          # Target Docker datasource
  registryUrls: string[];           # Custom registry URLs
  versioning: string;               # Versioning strategy
  rangeStrategy: string;            # Update strategy (pin, replace, etc.)
  respectLatest: boolean;           # Honor 'latest' tag semantics
  pinDigests: boolean;              # Pin to specific digests
  separateMultipleMajor: boolean;   # Separate PRs for major updates
  groupName: string;                # Group related updates
  schedule: string[];               # Update schedule
  labels: string[];                 # PR labels
  assignees: string[];              # PR assignees
}
```

### Host Rules for Registries
```typescript
// Authentication and registry-specific settings
{
  hostType: 'docker';
  matchHost: string;                # Registry hostname
  username: string;                 # Registry username
  password: string;                 # Registry password/token
  token: string;                    # Bearer token
  timeout: number;                  # Request timeout
  concurrentRequestLimit: number;   # Concurrent requests
  headers: object;                  # Custom headers
}
```

### Environment Variables
```bash
# Docker Hub optimizations
RENOVATE_X_DOCKER_HUB_TAGS_DISABLE=true          # Disable enhanced Docker Hub API
RENOVATE_X_DOCKER_HUB_DISABLE_LABEL_LOOKUP=true  # Skip label lookup for Docker Hub

# Authentication
DOCKER_REGISTRY_USER=username
DOCKER_REGISTRY_PASSWORD=password
RENOVATE_TOKEN=github_token

# AWS ECR
AWS_ACCESS_KEY_ID=key
AWS_SECRET_ACCESS_KEY=secret
AWS_REGION=region

# Google Cloud
GOOGLE_APPLICATION_CREDENTIALS=path/to/credentials.json
```

## Advanced Features

### 1. Multi-Stage Build Support
- Tracks stage names to avoid false dependencies
- Handles `COPY --from=stage` references
- Supports `RUN --mount=from=image` syntax

### 2. Variable Resolution
- Resolves ARG variables in FROM instructions
- Supports default values: `${VAR:-default}`
- Handles complex variable patterns

### 3. Registry-Specific Optimizations
- **Docker Hub**: Enhanced metadata API, label caching
- **Quay.io**: REST API fallback for pagination
- **AWS ECR**: Token-based authentication, result limits
- **Google GCR**: Service account authentication
- **Harbor/Artifactory**: Custom authentication flows

### 4. Digest and Multi-Architecture Support
- Automatic digest pinning
- Architecture-specific digest resolution
- Manifest list handling for multi-arch images

### 5. Caching Strategy
- **Registry API responses**: 28-day TTL for image configs
- **Tag lists**: Registry-specific caching
- **Docker Hub metadata**: Enhanced caching with reconciliation
- **Authentication tokens**: Memory-based caching

## Error Handling and Resilience

### 1. Authentication Failures
- Graceful fallback for public repositories
- Retry logic for token refresh
- Registry-specific error handling

### 2. Rate Limiting
- Built-in backoff for Docker Hub
- Configurable concurrent request limits
- Queue management for high-volume operations

### 3. Network Issues
- Timeout handling and retries
- Connection pooling and keep-alive
- Graceful degradation for partial failures

### 4. Registry Quirks
- Docker Hub library/ prefix handling
- Quay.io pagination workarounds
- ECR result size limitations
- Artifactory virtual repository support

This comprehensive analysis covers the complete Docker image upgrade process in Renovate, from initial parsing to final PR creation, including all configuration options and architectural considerations.

https://github.com/renovatebot/renovate 