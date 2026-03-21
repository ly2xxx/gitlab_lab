# Quick Start Guide - 10 Minute Demo

Get hands-on with Docker-in-Docker in just 10 minutes!

## Option 1: Local Testing (No GitLab Needed)

### Step 1: Test Locally with Docker Compose (5 minutes)

```powershell
# Navigate to lab directory
cd C:\code\gitlab_lab\labs\lab-22-dind-cicd

# Test DinD approach
docker-compose -f docker-compose-runner.yml up dind-demo

# Test Socket approach (faster)
docker-compose -f docker-compose-runner.yml up socket-demo

# Run comparison
docker-compose -f docker-compose-runner.yml up comparison

# Cleanup
docker-compose -f docker-compose-runner.yml down -v
```

**What you'll see:**
- DinD: ~10 second startup delay, then build
- Socket: Instant start, faster build
- Comparison: Side-by-side performance metrics

---

## Option 2: Run on GitLab (Full CI/CD)

### Step 2: Push to GitLab (5 minutes)

```powershell
# Initialize git
cd C:\code\gitlab_lab\labs\lab-22-dind-cicd
git init

# Create GitLab project at https://gitlab.com/projects/new

# Add remote (replace with your URL)
git remote add origin https://gitlab.com/your-username/dind-lab.git

# Choose which approach to test (start with DinD)
cp .gitlab-ci-dind.yml .gitlab-ci.yml

# Commit and push
git add .
git commit -m "Add DinD CI/CD lab"
git push -u origin main
```

### Step 3: Watch the Pipeline

1. Go to your GitLab project
2. Click **CI/CD** → **Pipelines**
3. Watch the pipeline run!
4. Check job logs to see DinD in action

### Step 4: Try Other Approaches

```powershell
# Test socket mount approach (if you have self-hosted runner)
git checkout -b socket-test
cp .gitlab-ci-socket.yml .gitlab-ci.yml
git add .gitlab-ci.yml
git commit -m "Test socket mount"
git push origin socket-test

# Test Kaniko approach
git checkout -b kaniko-test
cp .gitlab-ci-kaniko.yml .gitlab-ci.yml
git add .gitlab-ci.yml
git commit -m "Test Kaniko"
git push origin kaniko-test
```

---

## What to Look For

### In DinD Logs:
```
📦 Waiting for Docker daemon to initialize...
✅ Docker daemon ready!
🔨 Building Docker image with DinD...
```

### In Socket Logs:
```
⚡ Docker socket approach - instant daemon access!
✅ Docker daemon ready!  (no wait!)
🔨 Building Docker image with socket mount...
```

### In Kaniko Logs:
```
🚀 Building with Kaniko (no Docker daemon!)
📋 Kaniko version: v1.23.1
🔨 Building image with Kaniko...
```

---

## Performance Expectations

| Approach | Total Time | Notes |
|----------|------------|-------|
| **DinD** | ~30-40s | +10s daemon startup |
| **Socket** | ~15-25s | Instant start |
| **Kaniko** | ~25-35s | No daemon, pushes directly |

---

## Common Issues

### "Cannot connect to Docker daemon"
**Solution:** Wait longer for DinD
```yaml
before_script:
  - sleep 10  # Increase wait time
```

### "Permission denied: /var/run/docker.sock"
**For socket mount only - need runner configuration**
```toml
# Runner config.toml
volumes = ["/var/run/docker.sock:/var/run/docker.sock"]
```

### Kaniko "COPY failed"
**Solution:** Check context path
```yaml
--context "${CI_PROJECT_DIR}/app"
```

---

## Next Steps

After the quick demo:

1. **Read COMPARISON.md** - Deep dive into security/performance
2. **Try modifying the app** - See how builds change
3. **Test in your own projects** - Apply what you learned
4. **Review README.md** - Full lab with explanations

---

## Clean Up

```powershell
# Local docker compose
docker-compose -f docker-compose-runner.yml down -v

# Remove test images
docker rmi dind-demo:latest socket-demo:latest

# GitLab: Delete test project when done
```

---

**That's it!** You've now seen all three approaches to Docker-in-Docker in CI/CD. 🎉
