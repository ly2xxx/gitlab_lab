# GitLab Renovate Runner - Troubleshooting Guide

This guide provides solutions for common issues encountered when using GitLab Renovate Runner.

## Quick Diagnostics

### Run the Validation Script

First, run the comprehensive validation script:

```bash
./scripts/validate-setup.sh
```

This will check:
- GitLab connectivity
- Bot authentication
- Repository access
- Configuration files
- Docker image availability

## Common Issues and Solutions

### 1. Authentication Problems

#### Issue: "Authentication failed" or "Invalid token"

**Symptoms:**
- Pipeline jobs fail with authentication errors
- `curl` tests to GitLab API return 401 Unauthorized
- Renovate logs show token validation errors

**Solutions:**

1. **Check Token Validity**:
   ```bash
   # Test token manually
   curl -H "Private-Token: $RENOVATE_TOKEN" \
        "$GITLAB_URL/api/v4/user"
   
   # Should return user information, not error
   ```

2. **Verify Token Scopes**:
   - Required scopes: `api`, `read_user`, `read_repository`, `write_repository`
   - Go to: Profile → Preferences → Access Tokens
   - Check existing token or create new one

3. **Check Token Expiration**:
   - Tokens expire based on set date
   - Create new token if expired
   - Update CI/CD variable with new token

4. **Verify Bot Account Status**:
   ```bash
   # Check if bot account is active
   curl -H "Private-Token: $ADMIN_TOKEN" \
        "$GITLAB_URL/api/v4/users?username=renovate-bot"
   
   # Ensure "state": "active"
   ```

### 2. Repository Discovery Issues

#### Issue: "No repositories discovered" or "Empty repository list"

**Symptoms:**
- Renovate runs but finds no repositories to process
- Autodiscovery filter matches no repositories
- Pipeline completes quickly with no actions

**Solutions:**

1. **Test Autodiscovery Filter**:
   ```bash
   # Run autodiscovery test
   ./scripts/test-autodiscovery.sh
   
   # Try different filters
   export RENOVATE_AUTODISCOVER_FILTER="*/*"
   ./scripts/test-autodiscovery.sh
   ```

2. **Check Bot Repository Access**:
   ```bash
   # List repositories bot has access to
   curl -H "Private-Token: $RENOVATE_TOKEN" \
        "$GITLAB_URL/api/v4/projects?membership=true" | \
        jq -r '.[] | .path_with_namespace'
   ```

3. **Add Bot to Repositories**:
   - Go to each target repository
   - Project → Members → Invite members
   - Add `renovate-bot` with `Developer` role minimum

4. **Adjust Autodiscovery Filter**:
   ```yaml
   # Common filter patterns:
   RENOVATE_AUTODISCOVER_FILTER: "*/*"           # All repositories
   RENOVATE_AUTODISCOVER_FILTER: "my-group/*"    # Specific group
   RENOVATE_AUTODISCOVER_FILTER: "{group1/*,group2/*}"  # Multiple groups
   ```

### 3. Pipeline Execution Problems

#### Issue: Pipelines fail to start or run

**Symptoms:**
- Scheduled pipelines don't trigger
- Manual pipelines fail immediately
- Runner assignment issues

**Solutions:**

1. **Check Pipeline Schedules**:
   - Go to: Project → CI/CD → Schedules
   - Verify schedules are **Active**
   - Check cron pattern syntax
   - Ensure target branch exists

2. **Verify Runner Availability**:
   ```bash
   # Check available runners
   # Go to: Project → Settings → CI/CD → Runners
   # Ensure at least one runner is available
   ```

3. **Check Workflow Rules**:
   ```yaml
   # Ensure workflow rules allow execution
   workflow:
     rules:
       - if: '$CI_PIPELINE_SOURCE == "schedule"'
         when: always
       - if: '$CI_PIPELINE_SOURCE == "web"'
         when: always
   ```

4. **Resource Group Conflicts**:
   ```yaml
   # If multiple pipelines conflict, check resource group
   renovate:
     resource_group: renovate-execution
   ```

### 4. Configuration Issues

#### Issue: "Invalid configuration" or "Schema validation failed"

**Symptoms:**
- Renovate fails to parse configuration files
- JSON syntax errors in logs
- Configuration validation job fails

**Solutions:**

1. **Validate JSON Configuration**:
   ```bash
   # Check JSON syntax
   jq empty renovate.json
   
   # Use online validator
   npx renovate-config-validator renovate.json
   ```

2. **Validate JavaScript Configuration**:
   ```bash
   # Check syntax
   node -c config.js
   
   # Test loading
   node -e "console.log(JSON.stringify(require('./config.js'), null, 2))"
   ```

3. **Schema Validation**:
   ```bash
   # Download and validate against schema
   curl -o schema.json https://docs.renovatebot.com/renovate-schema.json
   npx ajv-cli validate -s schema.json -d renovate.json
   ```

4. **Common Configuration Fixes**:
   ```json
   {
     "$schema": "https://docs.renovatebot.com/renovate-schema.json",
     "extends": ["config:recommended"],
     "platform": "gitlab",
     "gitlabUrl": "http://localhost:8080"
   }
   ```

### 5. Merge Request Creation Issues

#### Issue: Renovate runs but doesn't create merge requests

**Symptoms:**
- Pipeline completes successfully
- No dependency updates found or MRs created
- Dependency dashboard shows no updates needed

**Solutions:**

1. **Check Dependency Files**:
   ```bash
   # Ensure repositories have dependency files
   # package.json, requirements.txt, composer.json, etc.
   
   # Verify files are in repository root or configured paths
   ```

2. **Test with Dry Run**:
   ```bash
   # Add to CI/CD variables for testing
   RENOVATE_DRY_RUN=full
   
   # Run pipeline to see what would be updated
   ```

3. **Check Update Types**:
   ```json
   {
     "packageRules": [
       {
         "matchUpdateTypes": ["major", "minor", "patch"],
         "enabled": true
       }
     ]
   }
   ```

4. **Verify Bot Permissions**:
   - Bot needs `Developer` role minimum to create MRs
   - Check repository-specific permissions
   - Verify no branch protection rules prevent bot actions

### 6. Performance Issues

#### Issue: Slow pipeline execution or timeouts

**Symptoms:**
- Pipelines take very long time to complete
- Timeout errors in jobs
- High resource usage

**Solutions:**

1. **Increase Timeout**:
   ```yaml
   renovate:
     timeout: 2h  # Increase from default
   ```

2. **Optimize Concurrency**:
   ```bash
   # Increase concurrent limits
   RENOVATE_PR_CONCURRENT_LIMIT=20
   RENOVATE_BRANCH_CONCURRENT_LIMIT=20
   ```

3. **Use Performance Template**:
   ```yaml
   include:
     - project: 'infrastructure/renovate-runner'
       file: '/templates/renovate-with-cache.yml'
   ```

4. **Enable Caching**:
   ```yaml
   cache:
     key: ${CI_COMMIT_REF_SLUG}-renovate
     paths:
       - renovate/cache/renovate/repository/
   ```

### 7. Network and Connectivity Issues

#### Issue: Network timeouts or connectivity problems

**Symptoms:**
- Timeout errors when accessing package registries
- DNS resolution failures
- SSL certificate errors

**Solutions:**

1. **Increase Timeouts**:
   ```json
   {
     "hostRules": [
       {
         "matchHost": "registry.npmjs.org",
         "timeout": 60000
       }
     ]
   }
   ```

2. **Configure Proxy (if needed)**:
   ```bash
   # In CI/CD variables if behind corporate proxy
   HTTP_PROXY=http://proxy.example.com:8080
   HTTPS_PROXY=http://proxy.example.com:8080
   NO_PROXY=localhost,gitlab.example.com
   ```

3. **SSL Certificate Issues**:
   ```bash
   # For self-signed certificates
   NODE_TLS_REJECT_UNAUTHORIZED=0  # Use only for testing
   
   # Better: Add certificates to image
   # COPY ca-certificates.crt /usr/local/share/ca-certificates/
   ```

## Advanced Troubleshooting

### Enable Debug Logging

```bash
# In CI/CD variables
LOG_LEVEL=debug

# Check detailed logs in pipeline artifacts
```

### Manual Renovate Execution

For debugging, run Renovate manually:

```bash
# Local testing (requires Docker)
docker run --rm \
  -e RENOVATE_TOKEN="$RENOVATE_TOKEN" \
  -e RENOVATE_PLATFORM=gitlab \
  -e RENOVATE_ENDPOINT="$GITLAB_URL/api/v4" \
  -e LOG_LEVEL=debug \
  ghcr.io/renovatebot/renovate:41 \
  --dry-run=full \
  --autodiscover=true
```

### Check GitLab Runner Resources

```bash
# Monitor runner resource usage
# GitLab Admin → Overview → Runners
# Check CPU and memory usage during execution
```

### Analyze Pipeline Artifacts

```bash
# Download and analyze log files
# Pipeline → Job → Browse artifacts
# Look for specific error patterns in renovate-log.ndjson
```

## Error Message Reference

### Common Error Messages and Solutions

| Error Message | Cause | Solution |
|---------------|-------|----------|
| `Authentication failed` | Invalid or expired token | Regenerate token with correct scopes |
| `Repository not found` | Bot lacks repository access | Add bot to repository with Developer role |
| `Rate limit exceeded` | Too many API calls | Reduce concurrency limits or add delays |
| `Network timeout` | Network connectivity issues | Increase timeout values |
| `Invalid JSON` | Malformed renovate.json | Validate JSON syntax |
| `Docker pull failed` | Image not available | Check image name and registry access |
| `Workflow rules blocked` | Pipeline rules prevent execution | Update workflow rules |
| `Resource group conflict` | Multiple pipelines running | Use resource groups or schedule conflicts |

## Getting Help

### Diagnostic Information to Collect

When seeking help, provide:

1. **Validation Script Output**:
   ```bash
   ./scripts/validate-setup.sh > diagnostics.txt 2>&1
   ```

2. **Pipeline Logs**:
   - Download job logs from failed pipeline
   - Include renovate-log.ndjson artifact

3. **Configuration Files**:
   - renovate.json or config.js
   - .gitlab-ci.yml (relevant sections)
   - CI/CD variables (redacted sensitive values)

4. **Environment Information**:
   - GitLab version
   - Runner type (shared/self-hosted)
   - Number of repositories
   - Error messages and timestamps

### Support Channels

1. **Official Documentation**:
   - [Renovate Documentation](https://docs.renovatebot.com/)
   - [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)

2. **Community Support**:
   - [Renovate Discussions](https://github.com/renovatebot/renovate/discussions)
   - [GitLab Community Forum](https://forum.gitlab.com/)

3. **Issue Tracking**:
   - [Renovate Issues](https://github.com/renovatebot/renovate/issues)
   - [GitLab Issues](https://gitlab.com/gitlab-org/gitlab/-/issues)

## Prevention Best Practices

### Regular Maintenance

1. **Token Rotation**:
   ```bash
   # Set calendar reminder to rotate tokens before expiry
   # Update CI/CD variables with new tokens
   ```

2. **Configuration Validation**:
   ```bash
   # Include config validation in CI/CD pipeline
   include:
     - project: 'infrastructure/renovate-runner'
       file: '/templates/renovate-config-validator.yml'
   ```

3. **Monitoring**:
   ```bash
   # Set up alerts for pipeline failures
   # Monitor execution time trends
   # Track success rates
   ```

### Configuration Management

1. **Use Version Control**:
   - Keep all configurations in Git
   - Use branches for configuration changes
   - Review configuration changes via MRs

2. **Environment Consistency**:
   - Use same configuration across environments
   - Test changes in non-production first
   - Document environment-specific variations

3. **Regular Updates**:
   - Update Renovate image versions regularly
   - Review and update configuration presets
   - Stay informed about Renovate changes