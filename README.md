# GitLab CI/CD Hands-on Tutorial

**A comprehensive, practical guide to mastering GitLab CI/CD pipelines**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitLab CI/CD](https://img.shields.io/badge/GitLab-CI%2FCD-orange.svg)](https://docs.gitlab.com/ee/ci/)
[![Hands-on Labs](https://img.shields.io/badge/Hands--on-Labs-blue.svg)](./labs/)

## 🎯 Overview

This tutorial provides a comprehensive, hands-on approach to learning GitLab CI/CD through practical labs and real-world examples. Whether you're new to CI/CD or looking to advance your GitLab skills, this tutorial will guide you through everything from basic pipeline concepts to advanced orchestration patterns.

## 🚀 What You'll Learn

- **Pipeline Fundamentals**: Stages, jobs, artifacts, and variables
- **Docker Integration**: Building, scanning, and deploying containers
- **Testing Strategies**: Unit, integration, E2E, and performance testing
- **Security Scanning**: SAST, DAST, dependency scanning, and compliance
- **Advanced Patterns**: Child pipelines, matrix builds, and orchestration
- **Production Deployment**: Best practices for reliable releases
- **Performance Optimization**: Caching, parallelization, and efficiency
- **GitLab Runner Management**: Setup, scaling, and maintenance

## 📚 Tutorial Structure

### **Beginner Level**
| Lab | Title | Duration | Concepts |
|-----|-------|----------|----------|
| [Lab 1](./labs/lab-01-basic-pipeline/) | Basic Pipeline Setup | 30 min | Jobs, stages, variables |
| [Lab 2](./labs/lab-02-stages-jobs/) | Stages and Jobs | 45 min | Dependencies, artifacts |
| [Lab 3](./labs/lab-03-variables-artifacts/) | Variables and Artifacts | 60 min | Environment variables, file passing |

### **Intermediate Level**
| Lab | Title | Duration | Concepts |
|-----|-------|----------|----------|
| [Lab 4](./labs/lab-04-docker-integration/) | Docker Integration | 90 min | Container builds, registry |
| [Lab 5](./labs/lab-05-testing-integration/) | Testing Integration | 75 min | Unit/integration tests, coverage |
| [Lab 6](./labs/lab-06-security-scanning/) | Security Scanning | 60 min | SAST, DAST, vulnerability management |

### **Advanced Level**
| Lab | Title | Duration | Concepts |
|-----|-------|----------|----------|
| [Lab 7](./labs/lab-07-advanced-patterns/) | Advanced Pipeline Patterns | 120 min | Child pipelines, matrix builds |
| [Lab 8](./labs/lab-08-runner-management/) | GitLab Runner Management | 90 min | Runner setup, scaling |

## 🛠️ Prerequisites

### Required Knowledge
- Basic understanding of Git and version control
- Command line/terminal familiarity
- Basic YAML syntax knowledge
- Understanding of software development lifecycle

### Technical Requirements
- GitLab account (GitLab.com or self-hosted)
- Git client installed locally
- Docker Desktop (for containerization labs)
- Code editor (VS Code recommended)
- Web browser for GitLab interface

### Recommended Setup
- **Windows 11**: Use WSL2 with Ubuntu for best experience
- **macOS**: Native terminal and Docker Desktop
- **Linux**: Native environment with Docker installed

## 🚀 Quick Start

### 1. Fork This Repository
```bash
# Fork the repository to your GitLab account
# Then clone your fork locally
git clone https://gitlab.com/your-username/gitlab_lab.git
cd gitlab_lab
```

### 2. Set Up Your Environment
```bash
# For Windows (use PowerShell as Administrator)
wsl --install  # Install WSL2 if not already installed
wsl  # Switch to WSL

# For all platforms - install Docker
# Download from: https://docs.docker.com/get-docker/

# Verify installations
git --version
docker --version
```

### 3. Start with Lab 1
```bash
# Navigate to the first lab
cd labs/lab-01-basic-pipeline

# Read the README and follow instructions
cat README.md
```

### 4. Enable GitLab CI/CD
1. Go to your GitLab project
2. Navigate to **Settings** → **CI/CD**
3. Ensure runners are available (GitLab.com provides shared runners)
4. Create or modify `.gitlab-ci.yml` as instructed in each lab

## 📄 Lab Overview

### **Lab 1: Basic Pipeline Setup** 🌱
Learn the fundamentals of GitLab CI/CD:
- Your first `.gitlab-ci.yml` file
- Understanding jobs and scripts
- Built-in variables and environment
- Pipeline execution basics

### **Lab 2: Stages and Jobs** 🔄
Organize your pipeline effectively:
- Pipeline stages and execution order
- Job dependencies and artifacts
- Parallel vs sequential execution
- Best practices for pipeline organization

### **Lab 3: Variables and Artifacts** 📦
Master data flow in pipelines:
- Global and job-level variables
- Environment-specific configurations
- Artifact creation and consumption
- File passing between jobs

### **Lab 4: Docker Integration** 🐳
Containerize your applications:
- Building Docker images in CI/CD
- GitLab Container Registry usage
- Multi-stage Docker builds
- Container security scanning

### **Lab 5: Testing Integration** 🧪
Implement comprehensive testing:
- Unit and integration test automation
- Code coverage reporting
- Quality gates and thresholds
- Test result visualization

### **Lab 6: Security Scanning** 🔒
Secure your applications:
- Static Application Security Testing (SAST)
- Dynamic Application Security Testing (DAST)
- Dependency vulnerability scanning
- Security quality gates

### **Lab 7: Advanced Pipeline Patterns** 🎨
Master complex workflows:
- Child and parent pipelines
- Matrix builds for cross-platform testing
- Dynamic pipeline generation
- Multi-project orchestration

### **Lab 8: GitLab Runner Management** 🏃
Optimize pipeline execution:
- Runner installation and configuration
- Scaling strategies
- Performance optimization
- Troubleshooting common issues

## 📊 Learning Path Recommendations

### **For Beginners**
1. Start with Labs 1-3 to build a solid foundation
2. Practice each concept thoroughly before moving on
3. Experiment with variations of the examples
4. Read GitLab documentation for deeper understanding

### **For Intermediate Users**
1. Review Labs 1-3 quickly if needed
2. Focus on Labs 4-6 for practical implementation skills
3. Apply concepts to your own projects
4. Explore GitLab security and testing features

### **For Advanced Users**
1. Jump to Labs 7-8 for advanced patterns
2. Use as reference for complex scenarios
3. Contribute improvements and additional examples
4. Share knowledge with your team

## 🛠️ Troubleshooting Guide

### Common Issues

**Pipeline doesn't start**
- Check `.gitlab-ci.yml` syntax using GitLab's CI Lint tool
- Verify runners are available and active
- Ensure project has CI/CD enabled

**Jobs fail with "command not found"**
- Check if the command is available in the Docker image
- Install required packages in `before_script`
- Use appropriate base images

**Artifacts not found in dependent jobs**
- Verify `dependencies:` list in job configuration
- Check artifact paths and expiration times
- Ensure source job completed successfully

**Docker build failures**
- Verify Dockerfile syntax and instructions
- Check if Docker-in-Docker service is configured
- Ensure proper registry authentication

### Getting Help

1. **Check the lab-specific README** for detailed instructions
2. **Use GitLab's CI Lint** to validate your YAML syntax
3. **Review pipeline logs** for specific error messages
4. **Consult GitLab documentation** for detailed reference
5. **Ask questions** in GitLab community forums

## 📚 Additional Resources

### Official Documentation
- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [GitLab CI/CD YAML Reference](https://docs.gitlab.com/ee/ci/yaml/)
- [GitLab Runner Documentation](https://docs.gitlab.com/runner/)

### Best Practices
- [GitLab CI/CD Best Practices](https://docs.gitlab.com/ee/ci/pipelines/pipeline_efficiency.html)
- [Security Best Practices](https://docs.gitlab.com/ee/security/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

### Community Resources
- [GitLab Community Forum](https://forum.gitlab.com/)
- [GitLab Blog](https://about.gitlab.com/blog/)
- [GitLab YouTube Channel](https://www.youtube.com/channel/UCnMGQ8QHMAnVIsI3xJrihhg)

## 👍 Contributing

We welcome contributions to improve this tutorial! Here's how you can help:

### Ways to Contribute
- **Fix bugs or typos** in documentation
- **Add new examples** or use cases
- **Improve existing labs** with better explanations
- **Create additional labs** for advanced topics
- **Share feedback** on your learning experience

### Contribution Process
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-improvement`)
3. Make your changes and test thoroughly
4. Commit with clear messages (`git commit -m 'Add amazing improvement'`)
5. Push to your branch (`git push origin feature/amazing-improvement`)
6. Create a merge request with detailed description

### Contribution Guidelines
- Follow existing documentation style and structure
- Test all code examples before submitting
- Include clear explanations for complex concepts
- Update the main README if adding new labs
- Ensure examples work with recent GitLab versions

## 📅 Changelog

### Version 1.0.0 (Current)
- Initial release with 8 comprehensive labs
- Covers beginner to advanced GitLab CI/CD concepts
- Includes practical examples and real-world scenarios
- Full documentation and troubleshooting guides

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **GitLab Team** for creating an amazing CI/CD platform
- **GitLab Community** for sharing knowledge and best practices
- **Contributors** who help improve this tutorial
- **Students and Teams** who provide valuable feedback

---

**Ready to master GitLab CI/CD?** 🚀

Start your journey with [Lab 1: Basic Pipeline Setup](./labs/lab-01-basic-pipeline/) and build your way up to advanced pipeline orchestration!

**Questions or feedback?** We'd love to hear from you! Create an issue or reach out to the community.

---

*This tutorial is continuously updated to reflect the latest GitLab CI/CD features and best practices.*