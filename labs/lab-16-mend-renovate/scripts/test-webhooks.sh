#!/bin/bash
set -e

# Webhook Testing Script for Mend Renovate Community Edition
# This script tests webhook functionality

echo "🔗 Testing Mend Renovate Webhook Integration"
echo "============================================"

# Load environment variables
if [ -f ".env" ]; then
    source .env
else
    echo "❌ .env file not found. Please run setup.sh first."
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Test basic webhook endpoint
test_webhook_endpoint() {
    log_info "Testing webhook endpoint availability..."
    
    WEBHOOK_URL="http://localhost:8090/webhook"
    
    if curl -s -f "$WEBHOOK_URL" > /dev/null 2>&1; then
        log_success "Webhook endpoint is reachable"
    else
        log_warning "Webhook endpoint is not accepting GET requests (this is expected)"
        log_info "Webhook endpoints typically only accept POST requests"
    fi
}

# Test webhook with push event
test_push_webhook() {
    log_info "Testing push event webhook..."
    
    WEBHOOK_URL="http://localhost:8090/webhook"
    WEBHOOK_SECRET="${MEND_RNV_WEBHOOK_SECRET:-renovate-webhook-secret}"
    
    PUSH_PAYLOAD='{
        "object_kind": "push",
        "event_name": "push",
        "before": "95790bf891e76fee5e1747ab589903a6a1f80f22",
        "after": "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
        "ref": "refs/heads/main",
        "checkout_sha": "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
        "user_id": 4,
        "user_name": "John Smith",
        "user_username": "jsmith",
        "user_email": "john@example.com",
        "user_avatar": "https://www.gravatar.com/avatar/example",
        "project_id": 15,
        "project": {
            "id": 15,
            "name": "renovate-test-project",
            "description": "Test project for Renovate",
            "web_url": "http://localhost:8080/root/renovate-test-project",
            "avatar_url": null,
            "git_ssh_url": "git@localhost:root/renovate-test-project.git",
            "git_http_url": "http://localhost:8080/root/renovate-test-project.git",
            "namespace": "root",
            "visibility_level": 20,
            "path_with_namespace": "root/renovate-test-project",
            "default_branch": "main",
            "ci_config_path": null,
            "homepage": "http://localhost:8080/root/renovate-test-project",
            "url": "git@localhost:root/renovate-test-project.git",
            "ssh_url": "git@localhost:root/renovate-test-project.git",
            "http_url": "http://localhost:8080/root/renovate-test-project.git"
        },
        "commits": [
            {
                "id": "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
                "message": "Update package.json dependencies",
                "title": "Update package.json dependencies",
                "timestamp": "2023-01-01T00:00:00+00:00",
                "url": "http://localhost:8080/root/renovate-test-project/-/commit/da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
                "author": {
                    "name": "John Smith",
                    "email": "john@example.com"
                },
                "added": [],
                "modified": ["package.json"],
                "removed": []
            }
        ],
        "total_commits_count": 1,
        "push_options": {},
        "repository": {
            "name": "renovate-test-project",
            "url": "git@localhost:root/renovate-test-project.git",
            "description": "Test project for Renovate",
            "homepage": "http://localhost:8080/root/renovate-test-project",
            "git_http_url": "http://localhost:8080/root/renovate-test-project.git",
            "git_ssh_url": "git@localhost:root/renovate-test-project.git",
            "visibility_level": 20
        }
    }'
    
    RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "X-Gitlab-Token: $WEBHOOK_SECRET" \
        -H "X-Gitlab-Event: Push Hook" \
        -d "$PUSH_PAYLOAD" \
        "$WEBHOOK_URL")
    
    HTTP_STATUS=$(echo "$RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    RESPONSE_BODY=$(echo "$RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "202" ]; then
        log_success "Push webhook test passed (HTTP $HTTP_STATUS)"
        log_info "Response: $RESPONSE_BODY"
    else
        log_warning "Push webhook returned HTTP $HTTP_STATUS"
        log_info "Response: $RESPONSE_BODY"
        log_info "This may be expected if the project doesn't exist or Renovate is not configured for it"
    fi
}

# Test webhook with merge request event
test_merge_request_webhook() {
    log_info "Testing merge request event webhook..."
    
    WEBHOOK_URL="http://localhost:8090/webhook"
    WEBHOOK_SECRET="${MEND_RNV_WEBHOOK_SECRET:-renovate-webhook-secret}"
    
    MR_PAYLOAD='{
        "object_kind": "merge_request",
        "event_type": "merge_request",
        "user": {
            "id": 1,
            "name": "Administrator",
            "username": "root",
            "state": "active",
            "avatar_url": "http://www.gravatar.com/avatar/avatar.png?s=80&d=identicon",
            "web_url": "http://localhost:8080/root"
        },
        "project": {
            "id": 1,
            "name": "renovate-test-project",
            "description": "Test project for Renovate",
            "web_url": "http://localhost:8080/root/renovate-test-project",
            "avatar_url": null,
            "git_ssh_url": "git@localhost:root/renovate-test-project.git",
            "git_http_url": "http://localhost:8080/root/renovate-test-project.git",
            "namespace": "root",
            "visibility_level": 20,
            "path_with_namespace": "root/renovate-test-project",
            "default_branch": "main",
            "homepage": "http://localhost:8080/root/renovate-test-project",
            "url": "git@localhost:root/renovate-test-project.git",
            "ssh_url": "git@localhost:root/renovate-test-project.git",
            "http_url": "http://localhost:8080/root/renovate-test-project.git"
        },
        "object_attributes": {
            "assignee_id": null,
            "author_id": 1,
            "created_at": "2023-01-01 00:00:00 UTC",
            "description": "Update Express.js to version 4.18.2",
            "head_pipeline_id": 123,
            "id": 99,
            "iid": 1,
            "last_edited_at": null,
            "last_edited_by_id": null,
            "merge_commit_sha": null,
            "merge_error": null,
            "merge_params": {
                "force_remove_source_branch": "1"
            },
            "merge_status": "can_be_merged",
            "merge_user_id": null,
            "merge_when_pipeline_succeeds": false,
            "milestone_id": null,
            "source_branch": "renovate/express-4.x",
            "source_project_id": 1,
            "state": "opened",
            "target_branch": "main",
            "target_project_id": 1,
            "time_estimate": 0,
            "title": "chore(deps): Update Express.js to v4.18.2",
            "updated_at": "2023-01-01 00:00:00 UTC",
            "updated_by_id": null,
            "url": "http://localhost:8080/root/renovate-test-project/-/merge_requests/1",
            "source": {
                "id": 1,
                "name": "renovate-test-project",
                "description": "Test project for Renovate",
                "web_url": "http://localhost:8080/root/renovate-test-project",
                "avatar_url": null,
                "git_ssh_url": "git@localhost:root/renovate-test-project.git",
                "git_http_url": "http://localhost:8080/root/renovate-test-project.git",
                "namespace": "root",
                "visibility_level": 20,
                "path_with_namespace": "root/renovate-test-project",
                "default_branch": "main",
                "homepage": "http://localhost:8080/root/renovate-test-project",
                "url": "git@localhost:root/renovate-test-project.git",
                "ssh_url": "git@localhost:root/renovate-test-project.git",
                "http_url": "http://localhost:8080/root/renovate-test-project.git"
            },
            "target": {
                "id": 1,
                "name": "renovate-test-project",
                "description": "Test project for Renovate",
                "web_url": "http://localhost:8080/root/renovate-test-project",
                "avatar_url": null,
                "git_ssh_url": "git@localhost:root/renovate-test-project.git",
                "git_http_url": "http://localhost:8080/root/renovate-test-project.git",
                "namespace": "root",
                "visibility_level": 20,
                "path_with_namespace": "root/renovate-test-project",
                "default_branch": "main",
                "homepage": "http://localhost:8080/root/renovate-test-project",
                "url": "git@localhost:root/renovate-test-project.git",
                "ssh_url": "git@localhost:root/renovate-test-project.git",
                "http_url": "http://localhost:8080/root/renovate-test-project.git"
            },
            "last_commit": {
                "id": "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
                "message": "chore(deps): Update Express.js to v4.18.2",
                "title": "chore(deps): Update Express.js to v4.18.2",
                "timestamp": "2023-01-01T00:00:00+00:00",
                "url": "http://localhost:8080/root/renovate-test-project/-/commit/da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
                "author": {
                    "name": "Renovate Bot",
                    "email": "renovate-bot@example.local"
                }
            },
            "work_in_progress": false,
            "total_time_spent": 0,
            "human_total_time_spent": null,
            "human_time_estimate": null,
            "assignee_ids": [],
            "reviewer_ids": [1],
            "labels": [
                {
                    "id": 206,
                    "title": "renovate",
                    "color": "#428BCA",
                    "project_id": 1,
                    "created_at": "2023-01-01T00:00:00.000Z",
                    "updated_at": "2023-01-01T00:00:00.000Z",
                    "template": false,
                    "description": "Automatic dependency updates by Renovate",
                    "type": "ProjectLabel",
                    "group_id": null
                }
            ],
            "state": "opened",
            "blocking_discussions_resolved": true,
            "draft": false
        },
        "labels": [
            {
                "id": 206,
                "title": "renovate",
                "color": "#428BCA",
                "project_id": 1,
                "created_at": "2023-01-01T00:00:00.000Z",
                "updated_at": "2023-01-01T00:00:00.000Z",
                "template": false,
                "description": "Automatic dependency updates by Renovate",
                "type": "ProjectLabel",
                "group_id": null
            }
        ],
        "changes": {
            "state": {
                "previous": null,
                "current": "opened"
            }
        },
        "repository": {
            "name": "renovate-test-project",
            "url": "git@localhost:root/renovate-test-project.git",
            "description": "Test project for Renovate",
            "homepage": "http://localhost:8080/root/renovate-test-project"
        }
    }'
    
    RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "X-Gitlab-Token: $WEBHOOK_SECRET" \
        -H "X-Gitlab-Event: Merge Request Hook" \
        -d "$MR_PAYLOAD" \
        "$WEBHOOK_URL")
    
    HTTP_STATUS=$(echo "$RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    RESPONSE_BODY=$(echo "$RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "202" ]; then
        log_success "Merge request webhook test passed (HTTP $HTTP_STATUS)"
        log_info "Response: $RESPONSE_BODY"
    else
        log_warning "Merge request webhook returned HTTP $HTTP_STATUS"
        log_info "Response: $RESPONSE_BODY"
    fi
}

# Test webhook with issues event (for dependency dashboard)
test_issues_webhook() {
    log_info "Testing issues event webhook (for dependency dashboard)..."
    
    WEBHOOK_URL="http://localhost:8090/webhook"
    WEBHOOK_SECRET="${MEND_RNV_WEBHOOK_SECRET:-renovate-webhook-secret}"
    
    ISSUE_PAYLOAD='{
        "object_kind": "issue",
        "event_type": "issue",
        "user": {
            "id": 2,
            "name": "Renovate Bot",
            "username": "renovate-bot",
            "state": "active",
            "avatar_url": "http://www.gravatar.com/avatar/avatar.png?s=80&d=identicon",
            "web_url": "http://localhost:8080/renovate-bot"
        },
        "project": {
            "id": 1,
            "name": "renovate-test-project",
            "description": "Test project for Renovate",
            "web_url": "http://localhost:8080/root/renovate-test-project",
            "avatar_url": null,
            "git_ssh_url": "git@localhost:root/renovate-test-project.git",
            "git_http_url": "http://localhost:8080/root/renovate-test-project.git",
            "namespace": "root",
            "visibility_level": 20,
            "path_with_namespace": "root/renovate-test-project",
            "default_branch": "main",
            "homepage": "http://localhost:8080/root/renovate-test-project",
            "url": "git@localhost:root/renovate-test-project.git",
            "ssh_url": "git@localhost:root/renovate-test-project.git",
            "http_url": "http://localhost:8080/root/renovate-test-project.git"
        },
        "object_attributes": {
            "assignee_id": null,
            "author_id": 2,
            "closed_at": null,
            "confidential": false,
            "created_at": "2023-01-01 00:00:00 UTC",
            "description": "This issue provides visibility into Renovate updates and dependencies.",
            "due_date": null,
            "id": 301,
            "iid": 1,
            "last_edited_at": null,
            "last_edited_by_id": null,
            "milestone_id": null,
            "moved_to_id": null,
            "duplicated_to_id": null,
            "position": 0,
            "previous_updated_at": "2023-01-01 00:00:00 UTC",
            "project_id": 1,
            "relative_position": null,
            "state": "opened",
            "time_estimate": 0,
            "title": "🤖 Dependency Dashboard",
            "updated_at": "2023-01-01 00:00:00 UTC",
            "updated_by_id": 2,
            "weight": null,
            "url": "http://localhost:8080/root/renovate-test-project/-/issues/1",
            "total_time_spent": 0,
            "time_change": 0,
            "human_total_time_spent": null,
            "human_time_estimate": null,
            "assignee_ids": [],
            "assignee_id": null,
            "labels": [
                {
                    "id": 206,
                    "title": "renovate",
                    "color": "#428BCA",
                    "project_id": 1,
                    "created_at": "2023-01-01T00:00:00.000Z",
                    "updated_at": "2023-01-01T00:00:00.000Z",
                    "template": false,
                    "description": "Renovate dependency updates",
                    "type": "ProjectLabel",
                    "group_id": null
                }
            ],
            "state": "opened",
            "severity": "UNKNOWN"
        },
        "labels": [
            {
                "id": 206,
                "title": "renovate",
                "color": "#428BCA",
                "project_id": 1,
                "created_at": "2023-01-01T00:00:00.000Z",
                "updated_at": "2023-01-01T00:00:00.000Z",
                "template": false,
                "description": "Renovate dependency updates",
                "type": "ProjectLabel",
                "group_id": null
            }
        ],
        "changes": {
            "state": {
                "previous": null,
                "current": "opened"
            }
        },
        "repository": {
            "name": "renovate-test-project",
            "url": "git@localhost:root/renovate-test-project.git",
            "description": "Test project for Renovate",
            "homepage": "http://localhost:8080/root/renovate-test-project"
        }
    }'
    
    RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "X-Gitlab-Token: $WEBHOOK_SECRET" \
        -H "X-Gitlab-Event: Issue Hook" \
        -d "$ISSUE_PAYLOAD" \
        "$WEBHOOK_URL")
    
    HTTP_STATUS=$(echo "$RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    RESPONSE_BODY=$(echo "$RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "202" ]; then
        log_success "Issues webhook test passed (HTTP $HTTP_STATUS)"
        log_info "Response: $RESPONSE_BODY"
    else
        log_warning "Issues webhook returned HTTP $HTTP_STATUS"
        log_info "Response: $RESPONSE_BODY"
    fi
}

# Monitor webhook activity in logs
monitor_webhook_logs() {
    log_info "Monitoring Renovate logs for webhook activity..."
    
    # Start monitoring logs in background
    docker-compose logs -f renovate-ce | grep -i "webhook\|event\|payload" &
    LOG_PID=$!
    
    echo "Monitoring logs for 10 seconds..."
    sleep 10
    
    # Stop log monitoring
    kill $LOG_PID 2>/dev/null || true
    
    log_info "Log monitoring completed. Check above output for webhook activity."
}

# Test webhook authentication
test_webhook_auth() {
    log_info "Testing webhook authentication..."
    
    WEBHOOK_URL="http://localhost:8090/webhook"
    WRONG_SECRET="wrong-secret"
    
    SIMPLE_PAYLOAD='{"object_kind": "test"}'
    
    # Test with wrong secret
    RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "X-Gitlab-Token: $WRONG_SECRET" \
        -d "$SIMPLE_PAYLOAD" \
        "$WEBHOOK_URL")
    
    HTTP_STATUS=$(echo "$RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    
    if [ "$HTTP_STATUS" = "401" ] || [ "$HTTP_STATUS" = "403" ]; then
        log_success "Webhook authentication is working (rejected wrong secret with HTTP $HTTP_STATUS)"
    else
        log_warning "Webhook authentication test returned HTTP $HTTP_STATUS (expected 401 or 403)"
    fi
    
    # Test with no secret
    RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$SIMPLE_PAYLOAD" \
        "$WEBHOOK_URL")
    
    HTTP_STATUS=$(echo "$RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    
    if [ "$HTTP_STATUS" = "401" ] || [ "$HTTP_STATUS" = "403" ]; then
        log_success "Webhook requires authentication (rejected request without secret)"
    else
        log_warning "Webhook without secret returned HTTP $HTTP_STATUS"
    fi
}

# Main test execution
run_webhook_tests() {
    echo "Starting webhook tests..."
    echo ""
    
    # Check if Renovate CE is running
    if ! docker-compose ps | grep -q "renovate-ce.*Up"; then
        log_error "Renovate CE is not running. Start it with: docker-compose up -d"
        exit 1
    fi
    
    # Run tests
    test_webhook_endpoint
    echo ""
    
    test_webhook_auth
    echo ""
    
    test_push_webhook
    echo ""
    
    test_merge_request_webhook
    echo ""
    
    test_issues_webhook
    echo ""
    
    monitor_webhook_logs
    echo ""
    
    echo "============================================"
    echo "Webhook Testing Summary"
    echo "============================================"
    echo "✅ All webhook tests completed"
    echo ""
    echo "To see real webhook activity:"
    echo "1. Create a project in GitLab with Renovate enabled"
    echo "2. Configure webhooks in project settings"
    echo "3. Push changes or create issues"
    echo "4. Monitor logs: docker-compose logs -f renovate-ce"
    echo ""
    echo "Webhook URL: http://localhost:8090/webhook"
    echo "Secret: ${MEND_RNV_WEBHOOK_SECRET:-renovate-webhook-secret}"
}

# Handle script interruption
trap 'echo "Webhook testing interrupted"; exit 1' INT

# Run main test function
run_webhook_tests "$@"
