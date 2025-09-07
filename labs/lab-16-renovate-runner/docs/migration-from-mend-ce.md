# Migration from Mend Renovate Community Edition to GitLab Renovate Runner

This guide helps you migrate from the traditional Mend Renovate CE (server-based) approach to the modern GitLab Renovate Runner (pipeline-based) solution.

## Why Migrate?

| Aspect | Mend CE (Old) | Renovate Runner (New) |
|--------|---------------|----------------------|
| **Architecture** | External server + webhooks | Native GitLab pipeline |
| **Resource Usage** | Always-on container | On-demand execution |
| **Maintenance** | Server updates, webhook management | Pipeline configuration only |
| **Scalability** | Limited by server resources | Scales with GitLab runners |
| **Cost** | Fixed infrastructure costs | Pay-per-execution |
| **Integration** | External webhook calls | Native GitLab CI/CD |
| **Reliability** | Single point of failure | Distributed pipeline execution |

## Pre-Migration Assessment

### Step 1: Document Current Setup

Before starting migration, document your current Mend CE setup:

```bash
# Document current configuration
cd ../lab-16-mend-renovate

# Save current environment variables
cat .env > mend-ce-config-backup.env

# Save Renovate configuration
cp renovate/config.js renovate-config-backup.js

# List repositories currently managed
docker-compose logs renovate-ce | grep "Processing repository" > managed-repos.txt
```

### Step 2: Verify Repository Access

```bash
# List all repositories the bot currently manages
curl -H "Private-Token: $MEND_RNV_GITLAB_PAT" \
     "$MEND_RNV_ENDPOINT/projects?membership=true" | \
     jq -r '.[] | .path_with_namespace'
```

## Migration Process

### Phase 1: Prepare New Environment

1. **Create Renovate Runner Project**:
   ```bash
   # Create new GitLab project for Renovate Runner
   # Name: renovate-runner
   # Visibility: Private
   
   git clone http://localhost:8080/infrastructure/renovate-runner.git
   cd renovate-runner
   
   # Copy the lab files
   cp -r ../gitlab_lab101/labs/lab-16-renovate-runner/* .
   ```

2. **Transfer Bot Account**:
   - Keep existing `renovate-bot` account
   - Verify Personal Access Token is still valid
   - Update token scopes if needed (api, read_user, read_repository, write_repository)

### Phase 2: Configuration Migration

1. **Convert Environment Variables**:
   ```bash
   # Create migration script
   cat > migrate-config.sh << 'EOF'
   #!/bin/bash
   
   # Read old Mend CE configuration
   source ../lab-16-mend-renovate/.env
   
   echo "# GitLab Renovate Runner Configuration (migrated from Mend CE)"
   echo "RENOVATE_TOKEN=$MEND_RNV_GITLAB_PAT"
   echo "GITHUB_COM_TOKEN=$GITHUB_COM_TOKEN"
   echo "RENOVATE_AUTODISCOVER_FILTER=${RENOVATE_AUTODISCOVER_FILTER:-*/*}"
   echo "LOG_LEVEL=${LOG_LEVEL:-info}"
   
   # Convert Mend-specific settings to standard Renovate settings
   if [ -n "$MEND_RNV_CRON_JOB_SCHEDULER" ]; then
       echo "# Schedule was: $MEND_RNV_CRON_JOB_SCHEDULER"
       echo "# Configure this in GitLab Pipeline Schedules instead"
   fi
   EOF
   
   chmod +x migrate-config.sh
   ./migrate-config.sh > renovate-runner.env
   ```

2. **Convert Renovate Configuration**:
   ```bash
   # Compare old and new configurations
   echo "=== Old Mend CE config.js ==="
   head -20 ../lab-16-mend-renovate/renovate/config.js
   
   echo "=== New Renovate Runner config.js ==="
   head -20 config.js
   
   # Merge custom settings from old configuration
   # Most settings should be compatible
   ```

### Phase 3: Repository-Level Migration

1. **Update Repository Configurations**:
   ```bash
   # For each repository with renovate.json, update GitLab-specific settings
   
   # Old Mend CE format:
   # {
   #   "gitlabUrl": "http://localhost:8080",
   #   "endpoint": "http://localhost:8080/api/v4/",
   #   ...
   # }
   
   # New format (these are handled automatically):
   # {
   #   "extends": ["config:recommended"],
   #   ...
   # }
   ```

2. **Remove Webhook Configurations**:
   ```bash
   # Remove webhooks from repositories (if manually configured)
   # GitLab project → Settings → Webhooks → Delete Renovate webhooks
   
   # The new pipeline-based approach doesn't use webhooks
   ```

### Phase 4: Pipeline Setup

1. **Configure CI/CD Variables**:
   ```bash
   # In renovate-runner project: Settings → CI/CD → Variables
   # Add variables from renovate-runner.env file
   ```

2. **Set Up Pipeline Schedules**:
   ```bash
   # GitLab project → CI/CD → Schedules → New Schedule
   # Use the same schedule as Mend CE CRON settings
   
   # Example: If MEND_RNV_CRON_JOB_SCHEDULER was "0 2 * * *"
   # Create schedule: "0 2 * * *" (2 AM daily)
   ```

### Phase 5: Gradual Migration

1. **Parallel Testing**:
   ```bash
   # Run both systems in parallel temporarily
   # Old Mend CE: Continue running for critical repositories
   # New Runner: Test with non-critical repositories first
   
   # Set different autodiscovery filters:
   # Mend CE: production/*
   # Runner: test/*,staging/*
   ```

2. **Monitor Both Systems**:
   ```bash
   # Monitor Mend CE logs
   docker-compose logs -f renovate-ce
   
   # Monitor Renovate Runner pipeline logs
   # GitLab project → CI/CD → Pipelines
   ```

### Phase 6: Full Migration

1. **Gradual Repository Transfer**:
   ```bash
   # Week 1: Test repositories
   export RENOVATE_AUTODISCOVER_FILTER="test/*"
   
   # Week 2: Development repositories  
   export RENOVATE_AUTODISCOVER_FILTER="{test/*,development/*}"
   
   # Week 3: Staging repositories
   export RENOVATE_AUTODISCOVER_FILTER="{test/*,development/*,staging/*}"
   
   # Week 4: Production repositories
   export RENOVATE_AUTODISCOVER_FILTER="*/*"
   ```

2. **Stop Mend CE**:
   ```bash
   # Only after confirming Renovate Runner works correctly
   cd ../lab-16-mend-renovate
   docker-compose down
   
   # Keep configuration as backup
   tar -czf mend-ce-backup-$(date +%Y%m%d).tar.gz .
   ```

## Verification Checklist

- [ ] Bot account has access to all target repositories
- [ ] Pipeline schedules configured and active
- [ ] First automated pipeline run successful
- [ ] Dependency dashboards created in target repositories
- [ ] Merge requests being created as expected
- [ ] No duplicate MRs from old and new systems
- [ ] Performance is acceptable (execution time, resource usage)
- [ ] All custom configuration migrated correctly
- [ ] Team familiar with new GitLab-based workflow

## Configuration Differences

### Mend CE vs Renovate Runner Settings

| Setting | Mend CE | Renovate Runner | Notes |
|---------|---------|-----------------|-------|
| **Scheduling** | `MEND_RNV_CRON_JOB_SCHEDULER` | GitLab Pipeline Schedule | Configure in GitLab UI |
| **Token** | `MEND_RNV_GITLAB_PAT` | `RENOVATE_TOKEN` | Same token, different variable name |
| **Endpoint** | `MEND_RNV_ENDPOINT` | Auto-detected from `CI_API_V4_URL` | No manual configuration needed |
| **Platform** | `MEND_RNV_PLATFORM` | Set in pipeline template | Hardcoded to `gitlab` |
| **Logging** | `LOG_LEVEL` | `LOG_LEVEL` | Same format |
| **Concurrency** | Server-limited | `RENOVATE_PR_CONCURRENT_LIMIT` | Configurable per run |
| **Webhooks** | Required | Not used | Pipeline-based triggers |

### Repository Configuration Changes

**Old (repository renovate.json)**:
```json
{
  "platform": "gitlab",
  "gitlabUrl": "http://localhost:8080",
  "endpoint": "http://localhost:8080/api/v4/",
  "token": "configured-in-server",
  "extends": ["config:recommended"]
}
```

**New (repository renovate.json)**:
```json
{
  "extends": ["config:recommended"],
  "labels": ["renovate", "dependencies"],
  "schedule": ["after 10pm every weekday", "every weekend"]
}
```

## Troubleshooting Migration Issues

### Common Problems and Solutions

1. **Duplicate Merge Requests**:
   ```bash
   # Problem: Both old and new systems creating MRs
   # Solution: Use different branch prefixes temporarily
   
   # In Mend CE config:
   "branchPrefix": "mend-renovate/"
   
   # In Renovate Runner config:
   "branchPrefix": "renovate/"
   ```

2. **Authentication Issues**:
   ```bash
   # Problem: Token not working in new system
   # Solution: Verify token scopes and regenerate if needed
   
   # Test token:
   curl -H "Private-Token: $RENOVATE_TOKEN" \
        "$GITLAB_URL/api/v4/user"
   ```

3. **Repository Access Issues**:
   ```bash
   # Problem: Bot cannot access repositories
   # Solution: Verify bot membership in target repositories
   
   ./scripts/test-autodiscovery.sh
   ```

4. **Performance Issues**:
   ```bash
   # Problem: New system slower than expected
   # Solution: Adjust concurrency limits
   
   # In CI/CD variables:
   RENOVATE_PR_CONCURRENT_LIMIT=20
   RENOVATE_BRANCH_CONCURRENT_LIMIT=20
   ```

## Rollback Plan

If migration issues occur:

1. **Emergency Rollback**:
   ```bash
   # Restart Mend CE immediately
   cd ../lab-16-mend-renovate
   docker-compose up -d
   
   # Disable Renovate Runner schedules
   # GitLab project → CI/CD → Schedules → Deactivate
   ```

2. **Investigate Issues**:
   ```bash
   # Check Renovate Runner logs
   # GitLab project → CI/CD → Pipelines → Job logs
   
   # Use validation script
   ./scripts/validate-setup.sh
   ```

3. **Gradual Recovery**:
   ```bash
   # Fix issues and re-attempt gradual migration
   # Start with test repositories again
   ```

## Post-Migration Cleanup

After successful migration:

1. **Remove Mend CE Infrastructure**:
   ```bash
   # Stop and remove containers
   cd ../lab-16-mend-renovate
   docker-compose down -v
   
   # Archive configuration
   tar -czf mend-ce-archive-$(date +%Y%m%d).tar.gz .
   
   # Optional: Remove directory after verification period
   ```

2. **Update Documentation**:
   - Update team runbooks
   - Document new pipeline-based workflow
   - Update incident response procedures

3. **Monitor Performance**:
   - Track pipeline execution times
   - Monitor resource usage
   - Collect team feedback

## Benefits Achieved

After migration, you should see:

- ✅ **Reduced Infrastructure**: No dedicated server maintenance
- ✅ **Better Integration**: Native GitLab workflow
- ✅ **Improved Scaling**: Automatic scaling with GitLab runners
- ✅ **Cost Optimization**: Pay-per-execution model
- ✅ **Enhanced Reliability**: Distributed execution, no single point of failure
- ✅ **Easier Management**: Pipeline-based configuration and monitoring

## Next Steps

- Set up monitoring and alerting for pipeline failures
- Optimize performance based on execution patterns
- Train team on new GitLab-native workflow
- Consider advanced features like custom approval workflows