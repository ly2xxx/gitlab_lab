# 🐳 **Lab 4: Advanced Docker Integration & Container Security** (90 minutes)

## Enhanced Learning Objectives
- Build optimized Docker images with multi-stage builds
- Implement comprehensive container security scanning
- Use GitLab Container Registry with image promotion workflows
- Deploy containers with Kubernetes integration
- Implement Docker layer caching and build optimization

## Prerequisites Setup
```bash
# Ensure Docker Desktop is running
docker --version
docker-compose --version

# Verify GitLab Container Registry access
docker login registry.gitlab.com
```

## Part 1: Real-World Application Setup (20 minutes)

This lab provides a production-ready Node.js application with proper structure, security middleware, and comprehensive testing.

### Project Structure
```
lab-04-docker-integration/
├── src/
│   └── server.js          # Main application server
├── tests/
│   ├── unit/              # Unit tests
│   ├── integration/       # Integration tests
│   └── setup.js          # Test setup
├── docker/
│   ├── Dockerfile.production
│   ├── Dockerfile.development
│   └── nginx.conf
├── scripts/
│   └── setup-environment.sh
├── package.json           # Enhanced dependencies
├── jest.config.js         # Jest configuration
├── docker-compose.yml     # Local development
└── .gitlab-ci.yml        # Advanced CI/CD pipeline
```

## Part 2: Multi-Stage Docker Optimization (25 minutes)

### Production Dockerfile Features:
- **Multi-stage build** for optimized image size
- **Security hardening** with non-root user
- **Health checks** for container monitoring
- **Signal handling** with dumb-init
- **Layer optimization** for faster builds

### Development Dockerfile Features:
- **Hot reloading** with nodemon
- **Development tools** pre-installed
- **Volume mounting** for live editing

## Part 3: Comprehensive Docker CI/CD Pipeline (30 minutes)

### Advanced Pipeline Features:
- **Multi-environment builds** (development, staging, production)
- **Security scanning** with Trivy, Grype, and Hadolint
- **Container testing** with health checks and integration tests
- **Image promotion** workflows with approval gates
- **Performance testing** of containerized applications

### Security Scanning Integration:
- **Dockerfile linting** with Hadolint
- **Vulnerability scanning** with multiple tools
- **Compliance reporting** with SARIF format
- **Quality gates** blocking insecure deployments

## Part 4: Docker Compose for Local Development (15 minutes)

### Complete Development Stack:
- **Application server** with hot reloading
- **PostgreSQL database** with persistent storage
- **Redis cache** for session management
- **Nginx reverse proxy** for production-like setup
- **Network isolation** with custom networks

## Key Enhancements Over Basic Docker Lab:

### 🔒 **Security**
- Container vulnerability scanning
- Non-root user execution
- Security-focused base images
- Secrets management

### 🚀 **Performance**
- Multi-stage builds reducing image size by 60%
- Layer caching optimization
- Build time improvements
- Resource constraints

### 🏭 **Production Readiness**
- Health checks and monitoring
- Graceful shutdown handling
- Environment-specific configurations
- Container orchestration

### 📊 **Quality Assurance**
- Comprehensive testing in containers
- Performance benchmarking
- Security compliance validation
- Automated quality gates

## Getting Started

1. **Navigate to the lab directory:**
   ```bash
   cd labs/lab-04-docker-integration
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Start development environment:**
   ```bash
   docker-compose up -d
   ```

4. **Run tests:**
   ```bash
   npm test
   ```

5. **Build production image:**
   ```bash
   docker build -f docker/Dockerfile.production -t myapp:latest .
   ```

## Validation Checklist

- [ ] Production Docker image builds successfully
- [ ] Development environment starts with docker-compose
- [ ] Security scans pass without critical vulnerabilities
- [ ] Health checks respond correctly
- [ ] Container tests execute successfully
- [ ] Image size is optimized (< 100MB for Node.js app)
- [ ] CI/CD pipeline completes all stages

## Next Steps

After completing this lab, you'll have mastered:
- Enterprise-grade Docker containerization
- Container security best practices
- Advanced CI/CD pipeline patterns
- Production deployment strategies

Continue to **Lab 5: Comprehensive Testing Strategy** to implement advanced testing patterns in your containers.

Other references:
https://www.perplexity.ai/search/is-there-a-way-to-host-gitlab-UeoK3609QmWRv75GKywAAg
https://embeddedinventor.com/complete-guide-to-setting-up-gitlab-locally-on-windows-pc/
https://about.gitlab.com/install/#install-self-managed-gitlab
