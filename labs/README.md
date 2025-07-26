# GitLab CI/CD Tutorial Labs

This directory contains hands-on labs designed to teach GitLab CI/CD concepts progressively, from basic pipeline setup to advanced orchestration patterns.

## 🎯 Lab Overview

Each lab builds upon previous concepts and includes:
- **Comprehensive README** with step-by-step instructions
- **Working example code** that you can run immediately
- **Complete `.gitlab-ci.yml`** configurations
- **Troubleshooting guides** for common issues
- **Expected results** and validation steps

## 🗺️ Learning Path

### 🌱 **Beginner Path** (Foundation)

**[Lab 1: Basic Pipeline Setup](./lab-01-basic-pipeline/)**
- Duration: ~30 minutes
- Learn: Jobs, scripts, variables, pipeline basics
- Outcome: Your first working GitLab CI/CD pipeline

**[Lab 2: Stages and Jobs](./lab-02-stages-jobs/)**
- Duration: ~45 minutes  
- Learn: Pipeline organization, dependencies, artifacts
- Outcome: Multi-stage pipeline with proper job orchestration

**[Lab 3: Variables and Artifacts](./lab-03-variables-artifacts/)**
- Duration: ~60 minutes
- Learn: Environment configuration, file passing, deployments
- Outcome: Environment-aware pipeline with artifact management

### 💪 **Intermediate Path** (Building Skills)

**[Lab 4: Docker Integration](./lab-04-docker-integration/)**
- Duration: ~90 minutes
- Learn: Container builds, registry, multi-stage builds
- Outcome: Containerized application with CI/CD automation

**[Lab 5: Testing Integration](./lab-05-testing-integration/)**
- Duration: ~75 minutes
- Learn: Automated testing, coverage, quality gates
- Outcome: Comprehensive testing pipeline with quality assurance

**[Lab 6: Security Scanning](./lab-06-security-scanning/)**
- Duration: ~60 minutes
- Learn: SAST, DAST, dependency scanning, security gates
- Outcome: Security-first pipeline with vulnerability management

### 🚀 **Advanced Path** (Mastery)

**[Lab 7: Advanced Pipeline Patterns](./lab-07-advanced-patterns/)**
- Duration: ~120 minutes
- Learn: Child pipelines, matrix builds, dynamic workflows
- Outcome: Complex pipeline orchestration and optimization

## 💻 Quick Start

### 1. Choose Your Starting Point

**New to CI/CD?** Start with Lab 1 and progress sequentially.

**Some CI/CD experience?** Review Labs 1-2 quickly, then focus on Labs 3-6.

**Advanced user?** Jump to Labs 6-7 for advanced patterns and optimizations.

### 2. Lab Setup Pattern

Each lab follows this consistent structure:

```
lab-XX-topic-name/
├── README.md              # Comprehensive guide and instructions
├── .gitlab-ci.yml         # Complete pipeline configuration
├── src/                   # Sample application code
├── tests/                 # Test files and examples
├── scripts/               # Helper scripts
└── docs/                  # Additional documentation
```

### 3. Running a Lab

1. **Navigate to the lab directory**:
   ```bash
   cd labs/lab-01-basic-pipeline
   ```

2. **Read the lab README**:
   ```bash
   cat README.md
   ```

3. **Copy files to your GitLab project**:
   ```bash
   # Copy the .gitlab-ci.yml to your project root
   cp .gitlab-ci.yml /path/to/your/project/
   ```

4. **Commit and push to trigger the pipeline**:
   ```bash
   git add .
   git commit -m "Add Lab X pipeline configuration"
   git push
   ```

5. **Monitor the pipeline** in GitLab UI:
   - Go to your project → CI/CD → Pipelines
   - Watch the pipeline execution and logs

## 📈 Learning Progression

### Core Concepts Covered

| Concept | Lab 1 | Lab 2 | Lab 3 | Lab 4 | Lab 5 | Lab 6 | Lab 7 |
|---------|-------|-------|-------|-------|-------|-------|-------|
| **Basic Pipeline** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Stages & Jobs** |   | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Variables** |   |   | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Artifacts** |   |   | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Docker Integration** |   |   |   | ✓ | ✓ | ✓ | ✓ |
| **Testing** |   |   |   |   | ✓ | ✓ | ✓ |
| **Security** |   |   |   |   |   | ✓ | ✓ |
| **Advanced Patterns** |   |   |   |   |   |   | ✓ |

### Skill Development Track

**After Lab 1:** You can create basic pipelines
**After Lab 2:** You can organize complex workflows  
**After Lab 3:** You can manage environments and deployments
**After Lab 4:** You can containerize and deploy applications
**After Lab 5:** You can implement comprehensive testing
**After Lab 6:** You can secure your applications
**After Lab 7:** You can architect complex CI/CD systems

## 🛠️ Common Setup

### Prerequisites for All Labs

1. **GitLab Account**: GitLab.com or self-hosted instance
2. **Git Client**: Latest version installed locally
3. **Code Editor**: VS Code recommended with GitLab extension
4. **Docker**: For containerization labs (4-7)

### Recommended Project Structure

For best results, organize your practice project like this:

```
your-gitlab-project/
├── .gitlab-ci.yml         # Your pipeline configuration
├── src/                   # Application source code
│   ├── app.js
│   └── calculator.js
├── tests/                 # Test files
│   ├── unit/
│   └── integration/
├── Dockerfile             # Container configuration
├── package.json           # Dependencies
└── README.md              # Project documentation
```

## 👥 Learning Modes

### 🏃 **Individual Learning**
- Work through labs at your own pace
- Experiment with variations
- Build your own examples

### 👥 **Team Learning**
- Assign different labs to team members
- Review and discuss implementations together
- Share knowledge and best practices

### 🏢 **Workshop Format**
- Use as structured training material
- Each lab can be a 1-hour session
- Include group discussions and Q&A

## 📊 Progress Tracking

### Completion Checklist

Track your progress through the labs:

- [ ] **Lab 1**: Basic Pipeline - Pipeline runs successfully
- [ ] **Lab 2**: Stages and Jobs - Multi-stage pipeline working
- [ ] **Lab 3**: Variables and Artifacts - Environment deployments
- [ ] **Lab 4**: Docker Integration - Container build and deploy
- [ ] **Lab 5**: Testing Integration - Tests running with coverage
- [ ] **Lab 6**: Security Scanning - Security scans passing
- [ ] **Lab 7**: Advanced Patterns - Complex workflow implemented

### Validation Steps

For each lab, ensure you can:
1. **Explain the concepts** covered in the lab
2. **Modify the examples** to fit different scenarios
3. **Troubleshoot issues** when things go wrong
4. **Apply the patterns** to real projects

## 🔍 Troubleshooting

### Common Issues Across Labs

**YAML Syntax Errors**
- Use GitLab's CI Lint tool: Project → CI/CD → Editor → Lint
- Check indentation (use spaces, not tabs)
- Validate YAML syntax online

**Runner Issues**
- Verify runners are available: Project → Settings → CI/CD → Runners
- Check runner tags if using specific runners
- Ensure runner has necessary permissions

**Job Failures**
- Check job logs for specific error messages
- Verify Docker image availability
- Confirm script permissions and file paths

### Getting Help

1. **Check the lab's README** for specific troubleshooting
2. **Review pipeline logs** in GitLab UI
3. **Use GitLab documentation** for detailed reference
4. **Ask in GitLab community** forums or Slack

## 🚀 Next Steps

After completing the labs:

1. **Apply to Real Projects**: Use learned patterns in actual work
2. **Explore GitLab Features**: Dive deeper into specific areas of interest
3. **Share Knowledge**: Teach others or contribute to the community
4. **Advanced Topics**: Explore GitLab's enterprise features
5. **Certification**: Consider GitLab certification programs

---

**Ready to start your GitLab CI/CD journey?** 🎆

Choose your starting lab and begin building your CI/CD expertise!

[Start with Lab 1 →](./lab-01-basic-pipeline/)