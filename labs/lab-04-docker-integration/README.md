# Lab 4: Docker Integration

## Objective
Learn how to integrate Docker into your GitLab CI/CD pipelines, including building images, using GitLab Container Registry, and implementing multi-stage builds.

## Prerequisites
- Completed [Lab 3: Variables and Artifacts](../lab-03-variables-artifacts/README.md)
- Basic understanding of Docker and containerization
- Docker concepts: images, containers, Dockerfile, layers

## What You'll Learn
- Building Docker images in GitLab CI/CD
- Using GitLab Container Registry
- Multi-stage Docker builds
- Docker image optimization
- Container scanning and security
- Docker-in-Docker (DinD) service

## Docker in GitLab CI/CD

GitLab provides several ways to work with Docker:

### 1. Docker-in-Docker (DinD)
- Run Docker commands inside Docker containers
- Full Docker functionality available
- Slightly slower due to virtualization overhead

### 2. Docker Socket Binding
- Mount Docker socket from host
- Faster than DinD
- Security considerations

### 3. GitLab Container Registry
- Integrated Docker registry
- Automatic authentication
- Free storage (with limits)

## Sample Application

First, let's create a simple Node.js application to containerize:

```javascript
// app.js
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from GitLab CI/CD Docker Lab!',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

app.listen(port, () => {
  console.log(`App listening at http://localhost:${port}`);
});
```

```json
{
  "name": "gitlab-docker-demo",
  "version": "1.0.0",
  "description": "Demo app for GitLab Docker integration",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "test": "echo \"No tests yet\" && exit 0"
  },
  "dependencies": {
    "express": "^4.18.0"
  }
}
```

## Lab Steps

### Step 1: Basic Docker Build

Create a simple Dockerfile:

```dockerfile
# Dockerfile
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY . .

# Expose port
EXPOSE 3000

# Set default environment
ENV NODE_ENV=production

# Start the application
CMD ["npm", "start"]
```

Basic pipeline with Docker build:

```yaml
stages:
  - build
  - test
  - deploy

variables:
  # Docker image configuration
  DOCKER_IMAGE_NAME: "$CI_PROJECT_NAME"
  DOCKER_TAG: "$CI_COMMIT_SHORT_SHA"
  
  # Docker driver configuration
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: "/certs"

# Use Docker-in-Docker service
services:
  - docker:24-dind

build_docker_image:
  stage: build
  image: docker:24
  before_script:
    - echo "Docker version:"
    - docker --version
    - echo "Logging into GitLab Container Registry..."
    - echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER --password-stdin $CI_REGISTRY
  script:
    - echo "Building Docker image: $DOCKER_IMAGE_NAME:$DOCKER_TAG"
    - docker build -t $CI_REGISTRY_IMAGE/$DOCKER_IMAGE_NAME:$DOCKER_TAG .
    - docker push $CI_REGISTRY_IMAGE/$DOCKER_IMAGE_NAME:$DOCKER_TAG
    - echo "Image pushed successfully!"
```

### Step 2: Multi-stage Docker Build

Optimized Dockerfile with multi-stage build:

```dockerfile
# Multi-stage Dockerfile
# Stage 1: Build stage
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev dependencies)
RUN npm ci

# Copy source code
COPY . .

# Run tests (optional)
RUN npm test

# Stage 2: Production stage
FROM node:18-alpine AS production

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install only production dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy application code from builder stage
COPY --from=builder --chown=nextjs:nodejs /app .

# Switch to non-root user
USER nextjs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => process.exit(res.statusCode === 200 ? 0 : 1))"

# Start the application
CMD ["npm", "start"]
```

### Step 3: Advanced Docker Pipeline

```yaml
stages:
  - validate
  - build
  - test
  - security
  - deploy

variables:
  # Docker configuration
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: "/certs"
  DOCKER_BUILDKIT: 1
  
  # Image configuration
  APP_NAME: "gitlab-docker-demo"
  IMAGE_TAG: "$CI_COMMIT_SHORT_SHA"
  LATEST_TAG: "latest"
  
  # Registry configuration
  REGISTRY_IMAGE: "$CI_REGISTRY_IMAGE/$APP_NAME"

services:
  - docker:24-dind

# Validate Dockerfile
validate_dockerfile:
  stage: validate
  image: hadolint/hadolint:latest-alpine
  script:
    - echo "Validating Dockerfile with hadolint..."
    - hadolint Dockerfile
    - echo "Dockerfile validation completed!"
  allow_failure: true

# Build multi-stage Docker image
build_image:
  stage: build
  image: docker:24
  before_script:
    - echo "Setting up Docker environment..."
    - docker info
    - echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER --password-stdin $CI_REGISTRY
    - echo "Docker environment ready!"
  script:
    - echo "Building multi-stage Docker image..."
    - echo "Image: $REGISTRY_IMAGE:$IMAGE_TAG"
    
    # Build with build arguments
    - >
      docker build 
      --target production 
      --build-arg NODE_ENV=production 
      --build-arg APP_VERSION=$CI_COMMIT_TAG 
      --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') 
      --build-arg VCS_REF=$CI_COMMIT_SHA 
      --tag $REGISTRY_IMAGE:$IMAGE_TAG 
      --tag $REGISTRY_IMAGE:$LATEST_TAG 
      .
    
    # Show image details
    - docker images $REGISTRY_IMAGE
    - docker history $REGISTRY_IMAGE:$IMAGE_TAG
    
    # Push images
    - docker push $REGISTRY_IMAGE:$IMAGE_TAG
    - docker push $REGISTRY_IMAGE:$LATEST_TAG
    
    - echo "Images pushed successfully!"
  artifacts:
    reports:
      # Store build information
    paths:
      - docker-build.log

# Test the Docker image
test_image:
  stage: test
  image: docker:24
  services:
    - docker:24-dind
  dependencies:
    - build_image
  before_script:
    - echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER --password-stdin $CI_REGISTRY
  script:
    - echo "Testing Docker image functionality..."
    
    # Pull the image
    - docker pull $REGISTRY_IMAGE:$IMAGE_TAG
    
    # Test image structure
    - echo "Image layers:"
    - docker history $REGISTRY_IMAGE:$IMAGE_TAG
    
    # Run basic functionality test
    - echo "Starting container for testing..."
    - docker run -d --name test-container -p 3000:3000 $REGISTRY_IMAGE:$IMAGE_TAG
    - sleep 10
    
    # Test health endpoint
    - docker exec test-container wget -qO- http://localhost:3000/health
    
    # Test main endpoint
    - docker exec test-container wget -qO- http://localhost:3000/
    
    # Check logs
    - docker logs test-container
    
    # Cleanup
    - docker stop test-container
    - docker rm test-container
    
    - echo "Image testing completed successfully!"

# Security scanning
security_scan:
  stage: security
  image: 
    name: aquasec/trivy:latest
    entrypoint: [""]
  dependencies:
    - build_image
  script:
    - echo "Scanning Docker image for vulnerabilities..."
    - trivy image --exit-code 0 --format template --template "@contrib/html.tpl" -o image-scan-report.html $REGISTRY_IMAGE:$IMAGE_TAG
    - trivy image --exit-code 1 --severity HIGH,CRITICAL $REGISTRY_IMAGE:$IMAGE_TAG
  artifacts:
    when: always
    paths:
      - image-scan-report.html
    expire_in: 1 week
  allow_failure: true

# Deploy to staging
deploy_staging:
  stage: deploy
  image: docker:24
  services:
    - docker:24-dind
  dependencies:
    - build_image
    - test_image
  before_script:
    - echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER --password-stdin $CI_REGISTRY
  script:
    - echo "Deploying to staging environment..."
    
    # Pull latest image
    - docker pull $REGISTRY_IMAGE:$IMAGE_TAG
    
    # Stop existing container if any
    - docker stop staging-app || true
    - docker rm staging-app || true
    
    # Run new container
    - >
      docker run -d 
      --name staging-app 
      -p 8080:3000 
      --restart unless-stopped 
      -e NODE_ENV=staging 
      -e APP_VERSION=$CI_COMMIT_TAG 
      $REGISTRY_IMAGE:$IMAGE_TAG
    
    # Wait for startup
    - sleep 15
    
    # Test deployment
    - docker exec staging-app wget -qO- http://localhost:3000/health
    
    - echo "Staging deployment completed!"
  environment:
    name: staging
    url: http://staging.example.com:8080
  when: on_success
```

### Step 4: Optimized Build with Cache

```yaml
# Optimized build with Docker layer caching
build_optimized:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  variables:
    DOCKER_BUILDKIT: 1
  before_script:
    - echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER --password-stdin $CI_REGISTRY
  script:
    - echo "Building with BuildKit and cache optimization..."
    
    # Build with cache from registry
    - >
      docker buildx build 
      --cache-from $REGISTRY_IMAGE:cache 
      --cache-to $REGISTRY_IMAGE:cache 
      --target production 
      --platform linux/amd64 
      --build-arg BUILDKIT_INLINE_CACHE=1 
      --tag $REGISTRY_IMAGE:$IMAGE_TAG 
      --tag $REGISTRY_IMAGE:$LATEST_TAG 
      --push 
      .
    
    - echo "Optimized build completed!"
```

## Docker Best Practices

### 1. Dockerfile Optimization
- Use multi-stage builds
- Minimize layers
- Use specific base image tags
- Run as non-root user
- Include health checks

### 2. Security
- Scan images for vulnerabilities
- Use minimal base images (Alpine)
- Don't include secrets in images
- Sign images (optional)

### 3. Performance
- Use Docker layer caching
- Optimize layer order
- Use .dockerignore
- Multi-platform builds when needed

### 4. CI/CD Integration
- Tag images meaningfully
- Clean up old images
- Use registry mirrors for faster pulls
- Implement proper error handling

## Common Issues & Solutions

**Issue**: "Cannot connect to Docker daemon"
- **Solution**: Ensure Docker service is running, check DinD configuration

**Issue**: "Permission denied" when pushing to registry
- **Solution**: Verify registry authentication, check CI/CD variables

**Issue**: Large image sizes
- **Solution**: Use multi-stage builds, minimize installed packages

**Issue**: Slow builds
- **Solution**: Use Docker layer caching, optimize Dockerfile layer order

**Issue**: Security vulnerabilities in image
- **Solution**: Use minimal base images, scan regularly, update dependencies

## Expected Results

1. **Docker Image**: Successfully built and pushed to GitLab Container Registry
2. **Multi-stage Build**: Optimized production image with minimal size
3. **Security Scanning**: Vulnerability report generated
4. **Testing**: Container functionality verified
5. **Deployment**: Application running in containerized environment

## Container Registry Usage

View your images in GitLab:
1. Go to your project → Packages & Registries → Container Registry
2. See image tags, sizes, and metadata
3. Pull commands for local development
4. Cleanup policies configuration

## Next Steps

Proceed to [Lab 5: Testing Integration](../lab-05-testing-integration/README.md) to learn about integrating various testing frameworks and quality gates.

## Reference

- [GitLab Docker Integration](https://docs.gitlab.com/ee/ci/docker/)
- [GitLab Container Registry](https://docs.gitlab.com/ee/user/packages/container_registry/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Multi-stage Builds](https://docs.docker.com/develop/multistage-build/)