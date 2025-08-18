# Lab 15: Component Usage Tracking

**A comprehensive solution for tracking GitLab CI component dependencies and managing component ecosystems in GitLab CE**

## 🎯 Overview

This lab demonstrates how to build a complete component dependency tracking system that solves the fundamental problem: **GitLab CE has no built-in way for component owners to see which projects are using their components or to notify consumers of updates.**

### Problem Statement
- Component owners cannot see which projects use their components
- No automatic notifications when components are updated
- No way to trigger testing in dependent projects
- Limited visibility into component adoption and usage patterns

### Solution Approach
Build a custom tracking system using GitLab CE's existing capabilities:
- **GitLab API** for project scanning and management
- **Webhooks** for real-time notifications
- **Pipeline triggers** for downstream testing
- **JSON registry** for dependency mapping

## 🏗️ Architecture

### Core Components

1. **Component Registry** (`registry/`)
   - Central database of components and their consumers
   - JSON-based storage using GitLab repository
   - Metadata about component versions and compatibility

2. **Discovery System** (`scripts/dependency-scanner.py`)
   - Automated scanning of GitLab projects
   - Detection of component usage patterns
   - Automatic registry updates

3. **Notification System** (`scripts/notification-sender.py`)
   - Consumer alerts for component updates
   - Issue creation in dependent projects
   - Webhook-based real-time notifications

4. **API Layer** (`api/`)
   - Extended GitLab API for component operations
   - REST-like interface for registry management
   - Webhook handlers for event processing

## 🚀 Quick Start

### 1. Set Up the Registry Project

```bash
# Clone or fork this repository
git clone <your-gitlab-instance>/labs/lab-15-component-usage-tracking
cd lab-15-component-usage-tracking

# Set up environment variables
export GITLAB_TOKEN="your-personal-access-token"
export GITLAB_URL="https://your-gitlab-instance.com"
export REGISTRY_PROJECT_ID="123"  # This project's ID
```

### 2. Initialize Component Registry

```bash
# Run the initial setup
python scripts/component-registry-manager.py init

# Register your first component
python scripts/component-registry-manager.py register-component \
  --name "helloworld" \
  --project "root/gitlab-lab-11-git-ops" \
  --path "templates/helloworld.yml" \
  --version "1.0.0"
```

### 3. Discover Existing Usage

```bash
# Scan for existing component usage
python scripts/dependency-scanner.py scan --component "helloworld"

# View current registry
python scripts/component-registry-manager.py list-consumers --component "helloworld"
```

## 📋 Component Owner Workflow

### Setup Component Tracking

Add this to your component project's `.gitlab-ci.yml`:

```yaml
include:
  - project: 'your-group/lab-15-component-usage-tracking'
    ref: main
    file: 'templates/notification-pipeline.yml'

variables:
  COMPONENT_NAME: "your-component-name"
  REGISTRY_PROJECT: "your-group/lab-15-component-usage-tracking"
```

### Track Component Updates

```yaml
# Automatically notify consumers on new releases
notify-consumers:
  stage: notify
  script:
    - python scripts/notification-sender.py notify-update \
        --component "$COMPONENT_NAME" \
        --version "$CI_COMMIT_TAG" \
        --changes "See CHANGELOG.md for details"
  rules:
    - if: $CI_COMMIT_TAG
```

### Trigger Downstream Testing

```yaml
test-dependents:
  stage: test-integration
  script:
    - python scripts/notification-sender.py trigger-tests \
        --component "$COMPONENT_NAME" \
        --test-ref "$CI_COMMIT_SHA"
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
```

## 👥 Consumer Project Workflow

### Register Component Usage

Add this one-time registration to your project:

```yaml
include:
  - project: 'your-group/lab-15-component-usage-tracking'
    ref: main
    file: 'templates/registration-template.yml'

register-component-usage:
  extends: .register-component
  variables:
    COMPONENT_NAME: "helloworld"
    COMPONENT_PROJECT: "root/gitlab-lab-11-git-ops"
    CONTACT_EMAIL: "$GITLAB_USER_EMAIL"
```

### Receive Update Notifications

The system will automatically:
- Create issues in your project when components are updated
- Trigger compatibility tests when requested
- Provide upgrade guidance for breaking changes

## 🔧 API Reference

### Component Registry Manager

```bash
# Register a new component
python scripts/component-registry-manager.py register-component \
  --name "component-name" \
  --project "group/project" \
  --path "templates/component.yml" \
  --version "1.0.0" \
  --description "Component description"

# Add consumer to component
python scripts/component-registry-manager.py add-consumer \
  --component "component-name" \
  --consumer-project "group/consumer-project" \
  --contact "user@example.com" \
  --version-used "1.0.0"

# List all consumers of a component
python scripts/component-registry-manager.py list-consumers \
  --component "component-name"

# Generate usage analytics
python scripts/component-registry-manager.py analytics \
  --component "component-name" \
  --format "json"
```

### Dependency Scanner

```bash
# Scan all accessible projects for component usage
python scripts/dependency-scanner.py scan-all

# Scan specific component
python scripts/dependency-scanner.py scan \
  --component "component-name"

# Scan specific project
python scripts/dependency-scanner.py scan-project \
  --project-id "123"

# Generate discovery report
python scripts/dependency-scanner.py report \
  --output "usage-report.json"
```

### Notification Sender

```bash
# Notify all consumers of component update
python scripts/notification-sender.py notify-update \
  --component "component-name" \
  --version "2.0.0" \
  --changes "Breaking changes: see migration guide" \
  --severity "major"

# Trigger testing in dependent projects
python scripts/notification-sender.py trigger-tests \
  --component "component-name" \
  --test-ref "commit-sha" \
  --test-type "compatibility"

# Send custom notification
python scripts/notification-sender.py custom \
  --component "component-name" \
  --title "Important Security Update" \
  --message "Please update to version 2.0.1 immediately"
```

## 📊 Registry Data Structure

### Component Definition

```json
{
  "name": "helloworld",
  "project": "root/gitlab-lab-11-git-ops",
  "path": "templates/helloworld.yml",
  "current_version": "1.0.0",
  "description": "Simple hello world component",
  "maintainer": "component-team@example.com",
  "created_at": "2024-01-15T10:00:00Z",
  "updated_at": "2024-01-15T10:00:00Z",
  "versions": [
    {
      "version": "1.0.0",
      "released_at": "2024-01-15T10:00:00Z",
      "changes": "Initial release",
      "breaking_changes": false
    }
  ],
  "usage_stats": {
    "total_consumers": 5,
    "active_consumers": 4,
    "last_scan": "2024-01-15T12:00:00Z"
  }
}
```

### Consumer Mapping

```json
{
  "component": "helloworld",
  "consumers": [
    {
      "project_id": 456,
      "project_path": "group/consumer-project",
      "contact": "dev-team@example.com",
      "version_used": "1.0.0",
      "include_method": "component",
      "registered_at": "2024-01-15T11:00:00Z",
      "last_seen": "2024-01-15T12:00:00Z",
      "status": "active"
    }
  ]
}
```

## 🔍 Monitoring and Analytics

### Usage Dashboard

The system provides analytics on:
- **Component adoption rates**: How quickly new versions are adopted
- **Usage patterns**: Which components are most popular
- **Dependency health**: Projects using outdated versions
- **Ecosystem growth**: New consumers over time

### Health Checks

```bash
# Check registry health
python scripts/component-registry-manager.py health-check

# Validate all component references
python scripts/dependency-scanner.py validate-registry

# Generate compatibility matrix
python scripts/component-registry-manager.py compatibility-matrix
```

## 🛠️ Advanced Configuration

### Custom Notification Templates

Create custom notification templates in `templates/notifications/`:

```yaml
# templates/notifications/security-update.yml
security-update:
  title: "🔒 Security Update: {{ component_name }} {{ version }}"
  description: |
    A security update is available for {{ component_name }}.
    
    **Severity**: {{ severity }}
    **CVE**: {{ cve_id }}
    **Action Required**: Update to version {{ version }} immediately
    
    See: {{ security_advisory_url }}
  labels:
    - security
    - urgent
    - component-update
```

### Webhook Configuration

Set up webhooks for real-time notifications:

```python
# api/webhook_handlers.py
@app.route('/webhook/component-update', methods=['POST'])
def handle_component_update():
    data = request.json
    component = data['component_name']
    version = data['version']
    
    # Notify all consumers immediately
    notify_consumers_async(component, version)
    
    return {'status': 'accepted'}, 202
```

## 🚨 Troubleshooting

### Common Issues

**Registry not updating**
- Check GitLab API token permissions
- Verify project access rights
- Check network connectivity to GitLab instance

**Consumers not receiving notifications**
- Verify webhook URLs are accessible
- Check project permissions for issue creation
- Validate email addresses in registry

**Scanner not finding components**
- Verify search permissions across projects
- Check component naming patterns
- Review include statement formats

### Debug Mode

Enable debug logging:

```bash
export DEBUG=true
export LOG_LEVEL=debug
python scripts/dependency-scanner.py scan --component "helloworld"
```

## 📈 Scaling Considerations

### Large Environments

For organizations with many components and consumers:

1. **Database Backend**: Replace JSON files with proper database
2. **Message Queue**: Add Redis/RabbitMQ for async processing
3. **API Rate Limiting**: Implement rate limiting for GitLab API calls
4. **Caching**: Add caching layer for frequently accessed data

### High Availability

- Deploy registry as redundant GitLab projects
- Use GitLab CI/CD for automated deployments
- Implement health checks and monitoring
- Set up backup and recovery procedures

## 🔮 Future Enhancements

### Planned Features

- **Web UI**: Browser-based dashboard for component management
- **Slack/Teams Integration**: Real-time notifications in team channels
- **Automated Testing**: Integration with component test suites
- **Version Compatibility**: Automated compatibility testing
- **Compliance Tracking**: Audit trails for component usage

### Integration Opportunities

- **GitLab Package Registry**: Store component metadata
- **GitLab Pages**: Host public component documentation
- **GitLab Container Registry**: Containerized component execution
- **GitLab Security**: Integration with vulnerability scanning

## 📚 Additional Resources

- [GitLab CI Components Documentation](https://docs.gitlab.com/ee/ci/components/)
- [GitLab API Documentation](https://docs.gitlab.com/ee/api/)
- [Component Best Practices Guide](../lab-14-component/USAGE-PATTERNS.md)
- [GitLab Webhooks](https://docs.gitlab.com/ee/user/project/integrations/webhooks.html)

## 🤝 Contributing

This lab is part of the GitLab CI/CD learning series. Contributions welcome!

1. Fork the repository
2. Create feature branch
3. Add tests for new functionality
4. Submit merge request with clear description

## 📄 License

This lab follows the same MIT license as the parent GitLab CI/CD tutorial repository.