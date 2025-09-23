# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building and Testing
- `pnpm build` - Build the project (runs clean, generate, compile, create-json-schema)
- `pnpm test` - Run complete test suite (lint, type-check, vitest)
- `pnpm vitest` - Run unit tests with Vitest
- `pnpm vitest <pattern>` - Run specific tests matching pattern (e.g., `pnpm vitest composer`)
- `pnpm vitest <pattern> -u` - Update snapshots for matching tests
- `pnpm lint` - Run all linting (ESLint, Prettier, type-check, markdown-lint)
- `pnpm lint-fix` - Auto-fix linting issues
- `pnpm type-check` - TypeScript type checking

### Development Environment
- `pnpm start` - Run Renovate locally (requires RENOVATE_TOKEN)
- `pnpm debug` - Run with Node.js debug inspector
- `LOG_LEVEL=debug pnpm start <repo>` - Run with debug logging

### Documentation
- `pnpm build:docs` - Generate documentation
- `pnpm mkdocs serve` - Serve docs locally (requires `pdm install` for MkDocs)
- `pnpm doc-fix` - Format documentation files

## High-Level Architecture

Renovate is an automated dependency update tool with a plugin-based architecture supporting 90+ package managers across multiple platforms.

### Core Components

#### Entry Point (`lib/renovate.ts`)
- Bootstrap process with telemetry instrumentation
- Main execution flow through global worker

#### Global Worker (`lib/workers/global/`)
- Orchestrates entire Renovate execution
- Handles configuration parsing and platform initialization
- Manages repository autodiscovery and processing
- Implements rate limiting and resource management

#### Repository Worker (`lib/workers/repository/`)
- Processes individual repositories
- Manages dependency extraction, update detection, and PR creation
- Handles branch management and conflict resolution

#### Module System (`lib/modules/`)
- **Datasources**: Retrieve version information from package registries (npm, Docker Hub, GitHub releases, etc.)
- **Managers**: Parse package files and extract dependencies (package.json, Dockerfile, pom.xml, etc.)
- **Platforms**: Interface with code hosting platforms (GitHub, GitLab, Bitbucket, etc.)
- **Versioning**: Handle different versioning schemes (semver, calendar, regex, etc.)

#### Configuration System (`lib/config/`)
- Hierarchical configuration with global, repository, and package-level settings
- Configuration migration and validation
- Preset resolution from multiple sources
- Schema generation and validation

### Key Design Patterns

#### Plugin Architecture
Each module type (datasource, manager, platform, versioning) follows a consistent plugin pattern:
- Export default configuration
- Implement required interface methods
- Self-contained with minimal dependencies
- Testable in isolation

#### Worker Pattern
- Global worker: handles platform-level operations
- Repository worker: processes individual repositories
- Separation allows for scaling and resource management

#### Configuration Inheritance
Configuration flows from global → repository → package rules → individual dependencies, with later stages overriding earlier ones.

### Testing Strategy

#### Test Organization
- Unit tests: `*.spec.ts` files co-located with source
- Test fixtures: `__fixtures__/` directories
- Mocks: `__mocks__/` directories and `test/` utilities
- 100% test coverage requirement

#### Test Utilities
- `test/setup.ts` - Global test configuration
- `test/http-mock.ts` - HTTP request mocking
- `test/fixtures.ts` - Common test data
- Vitest with Jest-compatible matchers and extended assertions

#### Running Tests
- Tests are sharded for CI performance
- Use `TEST_SHARD` environment variable for shard selection
- Coverage reports generated per shard and merged

## Common Development Patterns

### Adding a New Package Manager
1. Create directory in `lib/modules/manager/`
2. Implement `extract.ts` for dependency extraction
3. Add tests and fixtures
4. Export from `index.ts`
5. Update documentation

### Adding a New Datasource
1. Create directory in `lib/modules/datasource/`
2. Implement version fetching logic
3. Add schema validation if needed
4. Export from `index.ts`
5. Add comprehensive tests

### Configuration Options
- Add to `lib/config/options/index.ts`
- Include proper TypeScript types
- Document in `docs/usage/configuration-options.md`
- Consider migration path for breaking changes

### Error Handling
- Use structured logging with Bunyan
- Implement proper error types in `lib/types/errors/`
- Ensure errors are sanitized (no secrets in logs)
- Provide actionable error messages

## Key Files and Directories

- `lib/renovate.ts` - Main entry point
- `lib/workers/global/index.ts` - Global orchestration logic
- `lib/modules/` - Plugin system (datasources, managers, platforms, versioning)
- `lib/config/` - Configuration system and options
- `lib/util/` - Shared utilities (HTTP, Git, caching, etc.)
- `tools/` - Build and development tools
- `docs/development/` - Developer documentation
- `test/` - Test utilities and setup

## Development Environment

### Requirements
- Node.js ^22.13.0
- pnpm ^10.0.0
- Git ≥2.45.1
- C++ compiler (for native dependencies)

### Environment Variables
- `RENOVATE_TOKEN` - Platform access token for testing
- `LOG_LEVEL` - Logging level (fatal, error, warn, info, debug, trace)
- `GIT_ALLOW_PROTOCOL=file` - Allow file:// Git URLs in tests

### Testing Against Real Repositories
Create test repositories and run: `pnpm start <owner/repo>`
Example: `pnpm start r4harry/testrepo1`

## Build System

- TypeScript compilation with strict settings
- ESLint for code quality
- Prettier for formatting
- Vitest for testing
- Auto-generated schema and import files
- Docker support for containerized development