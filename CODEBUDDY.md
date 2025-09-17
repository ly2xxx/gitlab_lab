# CODEBUDDY.md

This file provides guidance to CodeBuddy Code when working with this GitLab CI/CD hands-on tutorial repository.

## Repository Overview

This is a **comprehensive GitLab CI/CD hands-on tutorial** repository containing 17 progressive labs that teach GitLab CI/CD concepts from basic pipelines to advanced enterprise patterns. The repository serves as both educational content and practical examples for developers learning DevOps practices.

## Development Commands

### Core Lab Testing Commands
```bash
# Test specific lab pipeline configurations
git add .gitlab-ci.yml
git commit -m "Test lab pipeline"
git push  # Triggers pipeline in GitLab

# Validate YAML syntax (use GitLab's CI Lint: Project → CI/CD → Editor → Lint)
```

### Node.js Labs (Labs 4-8, 12, 16-17)
```bash
# Install dependencies
npm install

# Run tests
npm test                    # All tests
npm run test:unit          # Unit tests only
npm run test:integration   # Integration tests only
npm run test:coverage     # Tests with coverage
npm run test:e2e          # End-to-end tests (Lab 5)
npm run test:performance  # Performance tests (Lab 5)
npm run test:all          # Complete test suite (Lab 5)

# Code quality
npm run lint              # ESLint validation
npm run lint:fix          # Auto-fix linting issues
npm run security-audit    # Security vulnerability check

# Docker operations
npm run docker:build      # Build production image
npm run docker:dev        # Start development environment
npm run docker:test       # Run tests in containers
```

### Shell Scripts
```bash
# Environment setup (Lab 4)
chmod +x scripts/setup-environment.sh
./scripts/setup-environment.sh

# Runner management (Lab 8)
chmod +x scripts/install-runner.sh
chmod +x scripts/register-runner.sh
chmod +x scripts/runner-maintenance.sh
./scripts/setup-enterprise-runners.sh

# GitOps operations (Lab 11)
chmod +x scripts/create-sample-files.sh
chmod +x scripts/update-image.sh

# Renovate bot setup (Labs 16)
chmod +x scripts/setup-bot-account.sh
chmod +x scripts/validate-setup.sh
```

### Docker Commands
```bash
# Multi-stage builds (Labs 4-8)
docker build -f docker/Dockerfile.development -t app:dev .
docker build -f docker/Dockerfile.production -t app:prod .

# Development environment
docker-compose up -d       # Start services
docker-compose down        # Stop services  
docker-compose logs -f     # View logs
```

## Architecture Overview

### Lab Structure Pattern
Each lab follows a consistent structure:
```
lab-XX-topic-name/
├── README.md              # Complete tutorial with step-by-step instructions
├── .gitlab-ci.yml         # Working pipeline configuration
├── src/                   # Sample application code
├── tests/                 # Test examples (unit, integration, e2e)
├── scripts/               # Helper automation scripts
├── docker/                # Container configurations (multi-stage)
├── config/                # Configuration files
└── .gitlab/               # Advanced pipeline configurations (Labs 7+)
```

### Pipeline Architecture Progression

**Labs 1-3: Foundation**
- Basic job execution and YAML syntax
- Multi-stage pipeline organization  
- Environment variables and artifact management
- Job dependencies and parallel execution

**Labs 4-6: Integration**
- Docker containerization with multi-stage builds
- Container registry integration
- Comprehensive testing strategies (unit, integration, e2e, performance)
- Security scanning (SAST, DAST, dependency scanning)
- Quality gates and thresholds

**Labs 7-8: Advanced Orchestration**
- Child and parent pipeline orchestration
- Matrix builds for cross-platform testing
- Dynamic pipeline generation
- GitLab Runner management and auto-scaling
- Enterprise-grade configurations

**Labs 9-17: Enterprise Patterns**
- Conditional pipelines and smart execution
- Evergreen pipelines with auto-updates
- GitOps workflows and deployment automation
- Component-based pipeline architecture
- Dependency management with Renovate
- Database migration with Liquibase

### Sample Applications

**Calculator API (Node.js/Express)**
- RESTful API with mathematical operations
- Comprehensive test coverage (Jest, Supertest, Cypress, Artillery)
- Docker containerization with health checks
- Security scanning integration
- Used in Labs 4-6

**Microservices Demo**
- Multiple service architectures with dependency mapping
- Complex pipeline orchestration with service discovery
- Cross-service integration testing
- Used in Labs 7-8, 12-13

## Key Technical Patterns

### GitLab CI/CD Features Demonstrated
- **Pipeline stages**: validate, build, test, security, deploy, verify
- **Job artifacts**: passing data between jobs with dependency management
- **Environment deployments**: staging, production with approval gates
- **Container registry**: image builds, scanning, and promotion
- **Security integrations**: GitLab SAST, DAST, dependency scanning, container scanning
- **Advanced patterns**: child pipelines, matrix builds, includes/extends, components
- **Dynamic pipelines**: service discovery and conditional execution

### Docker Integration
- Multi-stage Dockerfiles for development and production
- Container security scanning with GitLab
- Docker-in-Docker configurations
- Image optimization techniques
- Health check implementations
- Registry promotion workflows

### Testing Strategies
- **Unit testing**: Jest framework with coverage reporting
- **Integration testing**: API testing with Supertest
- **E2E testing**: Cypress automation (Lab 5)
- **Performance testing**: Artillery load testing (Lab 5)
- **Security testing**: Integrated SAST/DAST scanning (Lab 6)
- **Mutation testing**: Stryker integration (Lab 5)

### Quality Assurance
- ESLint with security-focused rules
- Code coverage thresholds and reporting
- Security vulnerability scanning with npm audit
- Quality gates preventing broken deployments
- Automated dependency updates with Renovate

## Working with Labs

### Development Workflow
1. Navigate to specific lab directory: `cd labs/lab-XX-topic/`
2. Read the comprehensive README.md for instructions
3. Copy `.gitlab-ci.yml` to your GitLab project
4. Follow step-by-step tutorial in lab README
5. Test pipeline execution in GitLab UI
6. Experiment with variations and advanced configurations

### Pipeline Validation
- Use GitLab's built-in CI Lint tool for YAML validation
- Check runner availability in Project → Settings → CI/CD → Runners
- Monitor pipeline execution in Project → CI/CD → Pipelines
- Review job logs for troubleshooting

### Common Commands for Lab Development
```bash
# Quick lab validation
cat README.md                    # Review lab instructions
gitlab-ci-lint .gitlab-ci.yml   # Validate YAML (if CLI available)

# Lab 4+ Node.js setup
npm install && npm test         # Validate application works

# Docker lab validation  
docker build -t test:latest .   # Test container builds
docker run --rm test:latest     # Test container execution
```

## Enterprise Features Covered

- **Auto-scaling runners**: Configuration and management (Lab 8)
- **Security compliance**: Integrated scanning and reporting (Lab 6)
- **Multi-project orchestration**: Child pipeline patterns (Labs 7, 12-13)
- **Performance optimization**: Caching, parallelization, efficient resource usage
- **Monitoring integration**: Prometheus/Grafana configurations (Lab 8)
- **GitOps workflows**: Automated deployment patterns (Lab 11)
- **Component architecture**: Reusable pipeline components (Labs 14-15)
- **Dependency management**: Automated updates with Renovate (Labs 16)

## Important Notes

- All lab examples are tested and functional
- Pipeline configurations follow GitLab CI/CD best practices
- Security scanning is integrated throughout (DevSecOps approach)
- Examples use widely-supported base images and tools
- Cross-platform compatibility maintained (Linux/Windows/macOS)
- Comprehensive troubleshooting guides included in each lab README

## Educational Progression

The labs are designed for progressive learning:
- **Beginners**: Start with Labs 0-3 for CI/CD foundations
- **Intermediate**: Focus on Labs 4-6 for practical implementation
- **Advanced**: Labs 7-8 for complex orchestration and management
- **Enterprise**: Labs 9-17 for production-ready patterns

Each lab includes validation steps, expected results, and troubleshooting sections to ensure successful completion.