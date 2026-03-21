# Lab 22: Docker-in-Docker (DinD) for CI/CD - Complete Guide

**Time to complete: ~60 minutes | Difficulty: Intermediate**

## 🎯 What You'll Learn

By completing this lab, you'll understand:
- **Docker-in-Docker (DinD)** - How it works and when to use it
- **Three approaches** to Docker in CI/CD (DinD, Socket Mount, Kaniko)
- **GitLab CI integration** with practical examples
- **Security trade-offs** between different approaches
- **Performance comparison** of each method

---

## 📋 Prerequisites

Before starting, ensure you have:

1. **Docker Desktop installed and running**
   ```bash
   docker --version  # Should show 20.10+ or newer
   ```

2. **GitLab account** (free tier works):
   - GitLab.com account OR
   - Self-hosted GitLab instance (see lab-00)

3. **Git configured:**
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

4. **Basic understanding of:**
   - Docker basics (images, containers, Dockerfile)
   - GitLab CI fundamentals (pipelines, jobs, stages)

---

## 📚 Background: The Problem

**Scenario:** You have a GitLab CI pipeline that needs to build Docker images.

**The catch:** Your GitLab Runner itself runs *inside a Docker container*.

**The question:** How does a container build another container?

### Three Solutions

| Approach | How It Works | Security | Performance |
|----------|--------------|----------|-------------|
| **DinD** | Nested Docker daemon | ⚠️ Needs `--privileged` | ⏱️ Slower (daemon startup) |
| **Socket Mount** | Share host's Docker | ⚠️ Can control host | ⚡ Fastest |
| **Kaniko** | Daemonless build | ✅ No privileges needed | ⏱️ Medium |

---

## 🚀 Lab Structure

This lab includes three working examples you can compare:

```
lab-22-dind-cicd/
├── README.md                          # This file
├── app/                               # Sample Node.js app
│   ├── Dockerfile
│   ├── package.json
│   └── server.js
├── .gitlab-ci-dind.yml               # Method 1: DinD
├── .gitlab-ci-socket.yml             # Method 2: Socket Mount
├── .gitlab-ci-kaniko.yml             # Method 3: Kaniko
├── docker-compose-runner.yml         # Local GitLab Runner for testing
└── COMPARISON.md                      # Detailed comparison
```

---

## 📖 Part 1: The Sample Application (10 min)

### Step 1.1: Review the App

We'll build a simple Node.js web server that returns "Hello from Docker!".

**File:** `app/server.js`
```javascript
const http = require('http');
const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(`
    <html>
      <body style="font-family: Arial; text-align: center; padding: 50px;">
        <h1>🐳 Hello from Docker!</h1>
        <p>Built with CI/CD using Docker-in-Docker</p>
        <p>Environment: ${process.env.NODE_ENV || 'development'}</p>
      </body>
    </html>
  `);
});

server.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
```

**File:** `app/Dockerfile`
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY server.js .
EXPOSE 3000
CMD ["node", "server.js"]
```

### Step 1.2: Test Locally

```bash
cd app
docker build -t hello-app:local .
docker run -p 3000:3000 hello-app:local

# Open browser: http://localhost:3000
# Press Ctrl+C to stop
```

---

## 🔧 Part 2: Method 1 - Docker-in-Docker (20 min)

### How It Works

```
┌──────────────────────────────────┐
│  GitLab Runner Container         │
│                                  │
│  ┌────────────────────────────┐ │
│  │  DinD Service Container    │ │
│  │  (docker:dind)             │ │
│  │                            │ │
│  │  [Nested Docker Daemon]    │ │
│  │  - Builds your image       │ │
│  │  - Isolated from host      │ │
│  └────────────────────────────┘ │
└──────────────────────────────────┘
```

### Step 2.1: Review GitLab CI Configuration

**File:** `.gitlab-ci-dind.yml`

```yaml
# Docker-in-Docker Approach
# Pros: Full isolation, safe for multi-tenant environments
# Cons: Slower startup, requires privileged mode

variables:
  # Tell Docker CLI where to find the DinD daemon
  DOCKER_HOST: tcp://docker:2376
  DOCKER_TLS_CERTDIR: "/certs"
  DOCKER_TLS_VERIFY: 1
  DOCKER_CERT_PATH: "$DOCKER_TLS_CERTDIR/client"

stages:
  - build
  - test
  - push

build:dind:
  stage: build
  image: docker:latest
  services:
    - docker:dind  # This starts the nested Docker daemon
  before_script:
    - echo "Waiting for Docker daemon to start..."
    - sleep 5  # DinD needs time to initialize
    - docker info  # Verify daemon is ready
  script:
    - cd app
    - echo "Building Docker image..."
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA .
    - docker build -t $CI_REGISTRY_IMAGE:latest .
    - docker images  # Show what was built
  artifacts:
    reports:
      dotenv: build.env

test:dind:
  stage: test
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - sleep 5
  script:
    - cd app
    - docker build -t test-app .
    - echo "Running container for testing..."
    - docker run -d --name test-container -p 3000:3000 test-app
    - sleep 2
    - docker ps
    - echo "Container started successfully!"
    - docker logs test-container
    - docker stop test-container

push:dind:
  stage: push
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - sleep 5
    - echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER --password-stdin $CI_REGISTRY
  script:
    - cd app
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
  only:
    - main
```

### Step 2.2: Push to GitLab

```bash
# Initialize git repo (if not already)
cd C:\code\gitlab_lab\labs\lab-22-dind-cicd
git init
git remote add origin https://gitlab.com/your-username/dind-lab.git

# Copy the DinD config as main .gitlab-ci.yml
cp .gitlab-ci-dind.yml .gitlab-ci.yml

git add .
git commit -m "Add DinD CI/CD example"
git push -u origin main
```

### Step 2.3: Watch the Pipeline

1. Go to your GitLab project → **CI/CD** → **Pipelines**
2. Watch the pipeline execute
3. Notice the ~5-10 second delay while DinD daemon starts
4. Check job logs - you'll see Docker daemon initialization

---

## ⚡ Part 3: Method 2 - Docker Socket Mount (15 min)

### How It Works

```
┌──────────────────────────────────┐
│  Host Docker Daemon              │
│  /var/run/docker.sock            │
└───────────┬──────────────────────┘
            │ (mounted into container)
            ▼
┌──────────────────────────────────┐
│  GitLab Runner Container         │
│                                  │
│  Uses HOST's Docker daemon       │
│  (no nested daemon needed)       │
└──────────────────────────────────┘
```

### Step 3.1: Review GitLab CI Configuration

**File:** `.gitlab-ci-socket.yml`

```yaml
# Docker Socket Mount Approach
# Pros: Fastest, shares host's image cache
# Cons: No isolation, security risk if untrusted code

variables:
  # No DOCKER_HOST needed - using local socket
  DOCKER_DRIVER: overlay2

stages:
  - build
  - test

build:socket:
  stage: build
  image: docker:latest
  # No services needed! Uses host Docker via mounted socket
  before_script:
    - docker info  # Instantly ready (no daemon startup)
  script:
    - cd app
    - docker build -t $CI_REGISTRY_IMAGE:socket-$CI_COMMIT_SHORT_SHA .
    - docker images
  tags:
    - docker-socket  # Runner must have socket mounted!

test:socket:
  stage: test
  image: docker:latest
  script:
    - cd app
    - docker build -t test-app .
    - docker run -d --name test-container test-app
    - docker logs test-container
    - docker stop test-container
    - docker rm test-container
  tags:
    - docker-socket
```

### Step 3.2: Configure GitLab Runner (Local Testing)

**Important:** This requires a GitLab Runner with Docker socket access.

**Option A: Using `docker-compose` (Recommended for local testing)**

**File:** `docker-compose-runner.yml`

```yaml
version: '3.8'

services:
  gitlab-runner:
    image: gitlab/gitlab-runner:latest
    container_name: gitlab-runner-socket
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # Mount host Docker socket
      - ./runner-config:/etc/gitlab-runner
    environment:
      - DOCKER_HOST=unix:///var/run/docker.sock

  # Example job using the mounted socket
  build-job:
    image: docker:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    working_dir: /app
    command: |
      sh -c "
        echo 'Docker socket approach - instant daemon access'
        docker info
        cd app && docker build -t demo:socket .
      "
```

### Step 3.3: Test Socket Mount Locally

```bash
# Windows PowerShell
docker run -v //var/run/docker.sock:/var/run/docker.sock docker:latest docker info

# You should see Docker info instantly (no wait time!)
```

---

## 🔒 Part 4: Method 3 - Kaniko (Daemonless) (15 min)

### How It Works

```
┌──────────────────────────────────┐
│  GitLab Runner Container         │
│                                  │
│  ┌────────────────────────────┐ │
│  │  Kaniko Executor           │ │
│  │  (No Docker daemon!)       │ │
│  │                            │ │
│  │  Builds image layer-by-    │ │
│  │  layer in userspace        │ │
│  └────────────────────────────┘ │
└──────────────────────────────────┘
```

### Step 4.1: Review GitLab CI Configuration

**File:** `.gitlab-ci-kaniko.yml`

```yaml
# Kaniko Approach
# Pros: No daemon needed, rootless, secure
# Cons: No container execution (build only), some Dockerfile features unsupported

stages:
  - build

build:kaniko:
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:latest
    entrypoint: [""]  # Override default entrypoint
  script:
    - echo "Building with Kaniko (no Docker daemon)..."
    - mkdir -p /kaniko/.docker
    # Configure registry auth
    - echo "{\"auths\":{\"$CI_REGISTRY\":{\"auth\":\"$(echo -n ${CI_REGISTRY_USER}:${CI_REGISTRY_PASSWORD} | base64)\"}}}" > /kaniko/.docker/config.json
    # Build and push in one step
    - /kaniko/executor
      --context ${CI_PROJECT_DIR}/app
      --dockerfile ${CI_PROJECT_DIR}/app/Dockerfile
      --destination ${CI_REGISTRY_IMAGE}:kaniko-${CI_COMMIT_SHORT_SHA}
      --destination ${CI_REGISTRY_IMAGE}:latest
      --cache=true
      --cache-repo=${CI_REGISTRY_IMAGE}/cache

# Note: Kaniko can't run containers, only build images
# So no test stage with `docker run` possible
```

---

## 📊 Part 5: Performance Comparison (10 min)

### Step 5.1: Run All Three Approaches

Create three separate GitLab projects (or three branches):

```bash
# Branch 1: DinD
git checkout -b dind-test
cp .gitlab-ci-dind.yml .gitlab-ci.yml
git add . && git commit -m "Test DinD" && git push origin dind-test

# Branch 2: Socket
git checkout -b socket-test
cp .gitlab-ci-socket.yml .gitlab-ci.yml
git add . && git commit -m "Test Socket" && git push origin socket-test

# Branch 3: Kaniko
git checkout -b kaniko-test
cp .gitlab-ci-kaniko.yml .gitlab-ci.yml
git add . && git commit -m "Test Kaniko" && git push origin kaniko-test
```

### Step 5.2: Measure Execution Times

| Method | Build Stage | Test Stage | Total | Notes |
|--------|-------------|------------|-------|-------|
| **DinD** | ~25s | ~20s | ~45s | +5-10s daemon startup |
| **Socket** | ~15s | ~10s | ~25s | Instant daemon access |
| **Kaniko** | ~20s | N/A | ~20s | No test stage (can't run containers) |

---

## 🔐 Part 6: Security Comparison

### DinD Security

**Risks:**
- ⚠️ Requires `--privileged` flag on runner
- ⚠️ Container can potentially escape to host (rare but possible)

**Mitigations:**
- ✅ Full isolation between jobs
- ✅ Each job gets clean slate (no cross-contamination)
- ✅ Safe for multi-tenant CI environments

**Best for:** Shared GitLab instances, untrusted code

---

### Socket Mount Security

**Risks:**
- 🚨 **Full control of host Docker daemon**
- 🚨 Can see/stop/delete ALL containers on host
- 🚨 Malicious pipeline could:
  - Mine cryptocurrency in background containers
  - Exfiltrate data from other containers
  - Crash host by consuming resources

**Example attack:**
```yaml
malicious_job:
  script:
    - docker run -d alpine sh -c "while true; do :; done"  # Hidden CPU hog
    - docker ps -a  # See ALL containers (even from other projects!)
```

**Best for:** Private runners, trusted code only

---

### Kaniko Security

**Risks:**
- ✅ Minimal! No daemon, no privileged mode
- ⚠️ Can still consume build resources

**Limitations:**
- ❌ Can't run containers (testing limited)
- ❌ Some Dockerfile features unsupported (e.g., `--network=host`)

**Best for:** Kubernetes, highly secure environments, image builds only

---

## 💡 When to Use Each Approach

| Scenario | Recommended Approach | Why |
|----------|---------------------|-----|
| **GitLab.com (shared runners)** | DinD or Kaniko | Isolation critical |
| **Private runners (trusted team)** | Socket Mount | Best performance |
| **Kubernetes CI** | Kaniko | No privileged pods |
| **Docker Compose testing** | DinD or Socket | Need to run containers |
| **Security-critical (banking, healthcare)** | Kaniko | Minimal attack surface |
| **High build volume** | Socket Mount | Speed matters |

---

## 🎓 Key Takeaways

1. **DinD = Isolation**
   - Safest for multi-user environments
   - Performance overhead acceptable for security gain

2. **Socket = Speed**
   - 2x faster than DinD
   - Only use with trusted code

3. **Kaniko = Future**
   - Modern, rootless approach
   - Limited to image building (no testing containers)

4. **There's no "best" solution**
   - Choose based on your security requirements
   - Performance vs. isolation trade-off

---

## 🆘 Troubleshooting

### DinD Issues

**Problem:** "Cannot connect to Docker daemon"
```yaml
before_script:
  - sleep 10  # Increase wait time for daemon startup
  - docker info || (sleep 5 && docker info)
```

**Problem:** "TLS handshake timeout"
```yaml
variables:
  DOCKER_TLS_CERTDIR: ""  # Disable TLS (less secure but sometimes needed)
```

---

### Socket Mount Issues

**Problem:** "Permission denied on /var/run/docker.sock"
```bash
# On runner host:
sudo chmod 666 /var/run/docker.sock
```

**Problem:** "Cannot find docker socket"
```yaml
# Ensure runner is configured with socket mount
# In GitLab Runner config.toml:
[[runners]]
  [runners.docker]
    volumes = ["/var/run/docker.sock:/var/run/docker.sock"]
```

---

### Kaniko Issues

**Problem:** "Error building image: COPY failed"
```dockerfile
# Kaniko requires explicit context
# Use --context flag:
/kaniko/executor --context $CI_PROJECT_DIR/app
```

---

## 📖 Next Steps

After completing this lab:

1. **Try in production:**
   - Deploy with your preferred method
   - Monitor build times and failure rates

2. **Advanced patterns:**
   - Multi-stage builds with caching
   - Parallel builds (DinD vs Kaniko)
   - Cross-platform builds (ARM + x86)

3. **Explore alternatives:**
   - BuildKit (Docker's modern builder)
   - Buildah + Podman (RedHat's tools)

---

## 📚 Additional Resources

- **GitLab CI Docker Best Practices:** https://docs.gitlab.com/ee/ci/docker/using_docker_build.html
- **Kaniko Documentation:** https://github.com/GoogleContainerTools/kaniko
- **Docker-in-Docker Security:** https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/
- **BuildKit:** https://github.com/moby/buildkit

---

**🎉 Congratulations!** You've mastered Docker-in-Docker for CI/CD and understand when to use each approach!
