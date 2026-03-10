# Configu + GitLab CI Integration Lab - Index

**Quick navigation for the complete lab**

---

## 📚 Documentation

| Document | Purpose | Read Time |
|----------|---------|-----------|
| **[README.md](README.md)** | Lab overview, quick start, examples | 15 min |
| **[SETUP.md](SETUP.md)** | Step-by-step setup instructions | 10 min |
| **[comparison.md](comparison.md)** | Deep dive: Option A vs Option B | 20 min |
| **INDEX.md** (this file) | Quick navigation | 2 min |

---

## 🛠️ Labs

### Option A: Export to .env File

**Location:** `option-a-env-export/`

**Files:**
- `.gitlab-ci.yml` - Pipeline with .env workflow
- `config.cfgu.json` - Configu schema
- `deploy.sh` - Deployment script
- `app.js` - Sample Node.js app

**Best for:**
- Docker Compose deployments
- Traditional VM deployments
- Teams new to Configu
- Simple shell script workflows

**Try it:**
```bash
cd option-a-env-export
configu export --set "development" --schema "./config.cfgu.json" > .env
source .env
node app.js
```

---

### Option B: Direct CLI Integration

**Location:** `option-b-direct-cli/`

**Files:**
- `.gitlab-ci.yml` - Pipeline with direct CLI
- `config.cfgu.json` - Configu schema
- `deploy.sh` - Deployment script
- `app.js` - Sample Node.js app

**Best for:**
- Kubernetes/Helm deployments
- Cloud-native workflows
- JSON/YAML configuration
- Maximum security (no file artifacts)

**Try it:**
```bash
cd option-b-direct-cli
configu eval --set "development" --schema "./config.cfgu.json" --format "export" | sh
node app.js
```

---

## 🎯 Quick Decision Guide

**Answer 3 questions:**

1. **Do you deploy to Kubernetes?**
   - Yes → **Option B**
   - No → Next question

2. **Do you use Docker Compose?**
   - Yes → **Option A**
   - No → Next question

3. **Is your team comfortable with jq and shell piping?**
   - Yes → **Option B**
   - No → **Option A**

---

## 📖 Learning Path

### Beginner (New to Configu)

1. **Read:** [README.md](README.md) - Overview
2. **Setup:** Follow [SETUP.md](SETUP.md)
3. **Try:** Option A (simpler)
4. **Run:** `node app.js` and explore endpoints
5. **Next:** Try Option B to compare

**Time:** ~1 hour

---

### Intermediate (Familiar with CI/CD)

1. **Read:** [comparison.md](comparison.md) - Deep dive
2. **Setup:** Both options from [SETUP.md](SETUP.md)
3. **Test:** Run both locally
4. **Compare:** Performance, workflow, output
5. **Choose:** Based on your stack

**Time:** ~2 hours

---

### Advanced (Ready to Deploy)

1. **Clone:** This lab to your repo
2. **Customize:** Update `config.cfgu.json` for your app
3. **Deploy:** Push to GitLab and trigger pipeline
4. **Monitor:** Watch CI/CD logs
5. **Iterate:** Refine based on results

**Time:** ~3 hours

---

## 🔗 Key Resources

### Internal

- [README.md](README.md) - Main documentation
- [SETUP.md](SETUP.md) - Installation guide
- [comparison.md](comparison.md) - Detailed comparison
- [option-a-env-export/.gitlab-ci.yml](option-a-env-export/.gitlab-ci.yml) - Option A pipeline
- [option-b-direct-cli/.gitlab-ci.yml](option-b-direct-cli/.gitlab-ci.yml) - Option B pipeline

### External

- **Configu Docs:** https://docs.configu.com
- **Configu CLI:** https://www.npmjs.com/package/@configu/cli
- **GitLab CI Docs:** https://docs.gitlab.com/ee/ci/
- **Configu + GitLab:** https://docs.configu.com/integrations/gitlab
- **jq Tutorial:** https://stedolan.github.io/jq/tutorial/

---

## 🧪 Testing Checklist

Use this checklist to validate both options:

### Option A

- [ ] Install Configu CLI
- [ ] Create config sets (dev/staging/prod)
- [ ] Export to .env file
- [ ] Source .env successfully
- [ ] Verify variables with `echo $API_URL`
- [ ] Run deploy.sh
- [ ] Run app.js
- [ ] Test all endpoints
- [ ] Cleanup .env file

### Option B

- [ ] Install Configu CLI + jq
- [ ] Create config sets
- [ ] Export via piped command
- [ ] Verify variables in shell
- [ ] Get JSON output with jq
- [ ] Run deploy.sh
- [ ] Run app.js with --config flag
- [ ] Test all endpoints
- [ ] Verify no artifacts left

---

## 🎓 What You'll Learn

### Technical Skills

- ✅ Configu CLI usage
- ✅ GitLab CI variable management
- ✅ Multi-environment configuration
- ✅ Secrets management best practices
- ✅ Docker/Kubernetes config patterns
- ✅ Shell scripting with jq
- ✅ Feature flag implementation

### Concepts

- ✅ Configuration as code
- ✅ Environment parity
- ✅ Separation of config from code
- ✅ Twelve-factor app principles
- ✅ GitOps workflows
- ✅ Audit trails and compliance

---

## 💬 Support

**Questions?**
1. Check [README.md](README.md) FAQ section
2. Review [comparison.md](comparison.md) for detailed explanations
3. Open an issue in the repo
4. Ask in Configu community: https://discord.gg/configu

**Found a bug?**
1. Check if it's in the known issues
2. Create a detailed bug report
3. Include: OS, Node version, Configu version, error logs

**Want to contribute?**
1. Fork the repo
2. Create a feature branch
3. Add your improvements
4. Submit a pull request

---

## 📊 Comparison Summary

| Feature | Option A | Option B |
|---------|----------|----------|
| **Ease of use** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Security** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Docker-friendly** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **K8s-friendly** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Debugging** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Performance** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

**Read full comparison:** [comparison.md](comparison.md)

---

## 🚀 Next Steps

After completing this lab:

1. **Adapt** - Customize for your real project
2. **Test** - Run in staging environment
3. **Monitor** - Track Configu usage and costs
4. **Scale** - Roll out to production
5. **Share** - Teach your team

---

## 📅 Lab Maintenance

**Last updated:** 2026-03-10  
**Configu CLI version:** Latest  
**GitLab CI version:** 15.0+  
**Node.js version:** 18.0+

**Changelog:**
- 2026-03-10: Initial lab creation
  - Added Option A (.env export)
  - Added Option B (direct CLI)
  - Created comprehensive docs

---

**Happy learning! 🎉**

Start with [SETUP.md](SETUP.md) →
