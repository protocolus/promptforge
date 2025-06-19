# GitHub Webhook Integration Examples

This document provides practical examples of integrating the webhook system with various workflows and services.

## CI/CD Integration

### Trigger Build on Push to Main

```bash
# Add to handle-github-event.sh
case "$EVENT_TYPE" in
    "push")
        BRANCH=$(echo "$PAYLOAD" | jq -r '.ref' | sed 's|refs/heads/||')
        if [ "$BRANCH" = "main" ]; then
            log_event "Triggering CI/CD build for main branch"
            
            # Jenkins example
            curl -X POST "https://jenkins.example.com/job/my-project/build" \
                -u "$JENKINS_USER:$JENKINS_TOKEN" \
                --data-urlencode json='{"parameter": [{"name":"GIT_COMMIT", "value":"'$(echo "$PAYLOAD" | jq -r '.after')'"}]}'
            
            # GitHub Actions example (trigger workflow)
            gh workflow run deploy.yml -f commit_sha=$(echo "$PAYLOAD" | jq -r '.after')
        fi
        ;;
esac
```

### Auto-Deploy on Release

```bash
# Add to handle-github-event.sh
case "$EVENT_TYPE" in
    "release")
        if [ "$ACTION" = "published" ]; then
            RELEASE_TAG=$(echo "$PAYLOAD" | jq -r '.release.tag_name')
            RELEASE_PRERELEASE=$(echo "$PAYLOAD" | jq -r '.release.prerelease')
            
            if [ "$RELEASE_PRERELEASE" = "false" ]; then
                log_event "Deploying release $RELEASE_TAG to production"
                
                # Trigger deployment
                ansible-playbook -i inventory/production deploy.yml \
                    -e "version=$RELEASE_TAG" \
                    >> "$LOG_DIR/deployments.log" 2>&1 &
            fi
        fi
        ;;
esac
```

## Slack Notifications

### Setup Slack Webhook

```bash
# Add to handle-github-event.sh (at the top)
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

send_slack_notification() {
    local text="$1"
    local color="${2:-#36a64f}"  # Default green
    
    curl -X POST "$SLACK_WEBHOOK_URL" \
        -H 'Content-Type: application/json' \
        -d '{
            "attachments": [{
                "color": "'"$color"'",
                "text": "'"$text"'",
                "footer": "GitHub Webhook",
                "ts": '$(date +%s)'
            }]
        }' 2>/dev/null
}
```

### Notify on Pull Request

```bash
case "$EVENT_TYPE" in
    "pull_request")
        PR_NUMBER=$(echo "$PAYLOAD" | jq -r '.pull_request.number')
        PR_TITLE=$(echo "$PAYLOAD" | jq -r '.pull_request.title')
        PR_USER=$(echo "$PAYLOAD" | jq -r '.pull_request.user.login')
        PR_URL=$(echo "$PAYLOAD" | jq -r '.pull_request.html_url')
        
        case "$ACTION" in
            "opened")
                send_slack_notification "🔵 New PR #$PR_NUMBER by $PR_USER: $PR_TITLE\n$PR_URL" "#0066cc"
                ;;
            "merged")
                send_slack_notification "✅ PR #$PR_NUMBER merged: $PR_TITLE\n$PR_URL" "#28a745"
                ;;
            "closed")
                if [ "$(echo "$PAYLOAD" | jq -r '.pull_request.merged')" = "false" ]; then
                    send_slack_notification "❌ PR #$PR_NUMBER closed without merging: $PR_TITLE" "#dc3545"
                fi
                ;;
        esac
        ;;
esac
```

## Database Tracking

### SQLite Event Storage

```bash
# Create database schema
cat > "$LOG_DIR/create_events_db.sql" << 'EOF'
CREATE TABLE IF NOT EXISTS github_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type TEXT NOT NULL,
    action TEXT,
    repository TEXT NOT NULL,
    sender TEXT NOT NULL,
    payload TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_event_type ON github_events(event_type);
CREATE INDEX idx_repository ON github_events(repository);
CREATE INDEX idx_created_at ON github_events(created_at);
EOF

# Initialize database
sqlite3 "$LOG_DIR/github_events.db" < "$LOG_DIR/create_events_db.sql"

# Add to handle-github-event.sh
log_to_database() {
    local sender=$(echo "$PAYLOAD" | jq -r '.sender.login // "unknown"')
    
    sqlite3 "$LOG_DIR/github_events.db" <<EOF
INSERT INTO github_events (event_type, action, repository, sender, payload)
VALUES ('$EVENT_TYPE', '$ACTION', '$REPO_NAME', '$sender', '$(echo "$PAYLOAD" | jq -c .)');
EOF
}

# Call in main script
log_to_database
```

### Query Events

```bash
# Recent push events
sqlite3 "$LOG_DIR/github_events.db" \
    "SELECT created_at, json_extract(payload, '$.pusher.name') as pusher
     FROM github_events 
     WHERE event_type = 'push' 
     ORDER BY created_at DESC 
     LIMIT 10;"

# Issues by user
sqlite3 "$LOG_DIR/github_events.db" \
    "SELECT sender, COUNT(*) as issue_count 
     FROM github_events 
     WHERE event_type = 'issues' 
     GROUP BY sender 
     ORDER BY issue_count DESC;"
```

## Security Scanning

### Scan on Push

```bash
case "$EVENT_TYPE" in
    "push")
        COMMIT_SHA=$(echo "$PAYLOAD" | jq -r '.after')
        
        # Trigger security scan
        log_event "Running security scan for commit $COMMIT_SHA"
        
        # Example: Trivy scan
        docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy image \
            --format json \
            --output "$LOG_DIR/security-scan-$COMMIT_SHA.json" \
            "ghcr.io/$REPO_NAME:$COMMIT_SHA" &
        
        # Example: GitHub code scanning
        gh api repos/$REPO_NAME/code-scanning/analyses \
            -X POST \
            -f ref="refs/heads/main" \
            -f commit_sha="$COMMIT_SHA" \
            -f tool_name="custom-scanner" &
        ;;
esac
```

## Metrics Collection

### Prometheus Metrics

```bash
# Add to handle-github-event.sh
METRICS_FILE="$LOG_DIR/github_metrics.prom"

# Initialize metrics file
init_metrics() {
    cat > "$METRICS_FILE" << 'EOF'
# HELP github_webhook_events_total Total number of GitHub webhook events received
# TYPE github_webhook_events_total counter
EOF
}

# Update metrics
update_metrics() {
    local event_type="$1"
    local action="${2:-none}"
    
    # Update or add metric
    local metric_name="github_webhook_events_total{event=\"$event_type\",action=\"$action\"}"
    local current_value=$(grep "^$metric_name" "$METRICS_FILE" | awk '{print $2}' || echo "0")
    local new_value=$((current_value + 1))
    
    # Update file
    grep -v "^$metric_name" "$METRICS_FILE" > "$METRICS_FILE.tmp" || true
    echo "$metric_name $new_value" >> "$METRICS_FILE.tmp"
    mv "$METRICS_FILE.tmp" "$METRICS_FILE"
}

# Call in main script
update_metrics "$EVENT_TYPE" "$ACTION"
```

### Grafana Dashboard Query

```promql
# Events per hour
rate(github_webhook_events_total[1h])

# Top event types
topk(10, sum by (event) (github_webhook_events_total))

# Pull request activity
sum by (action) (github_webhook_events_total{event="pull_request"})
```

## Issue Management

### Auto-Label Issues

```bash
case "$EVENT_TYPE" in
    "issues")
        if [ "$ACTION" = "opened" ]; then
            ISSUE_NUMBER=$(echo "$PAYLOAD" | jq -r '.issue.number')
            ISSUE_TITLE=$(echo "$PAYLOAD" | jq -r '.issue.title')
            ISSUE_BODY=$(echo "$PAYLOAD" | jq -r '.issue.body')
            
            # Auto-label based on keywords
            if echo "$ISSUE_TITLE $ISSUE_BODY" | grep -qi "bug\|error\|crash\|fail"; then
                gh issue edit "$ISSUE_NUMBER" --add-label "bug" -R "$REPO_NAME"
            fi
            
            if echo "$ISSUE_TITLE $ISSUE_BODY" | grep -qi "feature\|enhancement\|request"; then
                gh issue edit "$ISSUE_NUMBER" --add-label "enhancement" -R "$REPO_NAME"
            fi
            
            if echo "$ISSUE_TITLE $ISSUE_BODY" | grep -qi "documentation\|docs\|readme"; then
                gh issue edit "$ISSUE_NUMBER" --add-label "documentation" -R "$REPO_NAME"
            fi
        fi
        ;;
esac
```

### Auto-Assign Issues

```bash
# Mapping of labels to assignees
declare -A LABEL_ASSIGNEES=(
    ["bug"]="dev-team"
    ["documentation"]="docs-team"
    ["security"]="security-team"
)

case "$EVENT_TYPE" in
    "issues")
        if [ "$ACTION" = "labeled" ]; then
            ISSUE_NUMBER=$(echo "$PAYLOAD" | jq -r '.issue.number')
            LABEL_NAME=$(echo "$PAYLOAD" | jq -r '.label.name')
            
            # Check if we have an assignee for this label
            if [ -n "${LABEL_ASSIGNEES[$LABEL_NAME]}" ]; then
                ASSIGNEE="${LABEL_ASSIGNEES[$LABEL_NAME]}"
                gh issue edit "$ISSUE_NUMBER" \
                    --add-assignee "$ASSIGNEE" \
                    -R "$REPO_NAME"
                log_event "Auto-assigned issue #$ISSUE_NUMBER to $ASSIGNEE based on label $LABEL_NAME"
            fi
        fi
        ;;
esac
```

## Custom Workflows

### PR Review Reminder

```bash
case "$EVENT_TYPE" in
    "pull_request")
        if [ "$ACTION" = "opened" ] || [ "$ACTION" = "ready_for_review" ]; then
            PR_NUMBER=$(echo "$PAYLOAD" | jq -r '.pull_request.number')
            
            # Schedule reminder for 24 hours later
            echo "gh pr comment $PR_NUMBER -R $REPO_NAME -b 'Friendly reminder: This PR is awaiting review! 🕐'" | \
                at now + 24 hours 2>/dev/null
            
            log_event "Scheduled review reminder for PR #$PR_NUMBER"
        fi
        ;;
esac
```

### Dependency Update Automation

```bash
case "$EVENT_TYPE" in
    "pull_request")
        PR_TITLE=$(echo "$PAYLOAD" | jq -r '.pull_request.title')
        PR_NUMBER=$(echo "$PAYLOAD" | jq -r '.pull_request.number')
        PR_USER=$(echo "$PAYLOAD" | jq -r '.pull_request.user.login')
        
        # Auto-merge dependabot PRs for patch updates
        if [ "$PR_USER" = "dependabot[bot]" ] && [ "$ACTION" = "opened" ]; then
            if echo "$PR_TITLE" | grep -q "Bump.*from.*to.*patch"; then
                # Wait for checks to pass then merge
                gh pr merge "$PR_NUMBER" \
                    --auto \
                    --merge \
                    -R "$REPO_NAME"
                log_event "Auto-merge enabled for Dependabot PR #$PR_NUMBER"
            fi
        fi
        ;;
esac
```

## Email Notifications

```bash
# Email configuration
SMTP_SERVER="smtp.gmail.com"
SMTP_PORT="587"
EMAIL_FROM="webhook@example.com"
EMAIL_TO="team@example.com"

send_email_notification() {
    local subject="$1"
    local body="$2"
    
    # Using sendmail
    {
        echo "From: $EMAIL_FROM"
        echo "To: $EMAIL_TO"
        echo "Subject: $subject"
        echo "Content-Type: text/plain"
        echo ""
        echo "$body"
    } | sendmail -t
    
    # Or using mail command
    # echo "$body" | mail -s "$subject" "$EMAIL_TO"
}

# Send email for releases
case "$EVENT_TYPE" in
    "release")
        if [ "$ACTION" = "published" ]; then
            RELEASE_TAG=$(echo "$PAYLOAD" | jq -r '.release.tag_name')
            RELEASE_NAME=$(echo "$PAYLOAD" | jq -r '.release.name')
            RELEASE_URL=$(echo "$PAYLOAD" | jq -r '.release.html_url')
            
            send_email_notification \
                "New Release: $RELEASE_NAME ($RELEASE_TAG)" \
                "A new release has been published for $REPO_NAME.\n\nRelease: $RELEASE_NAME\nTag: $RELEASE_TAG\nURL: $RELEASE_URL"
        fi
        ;;
esac
```

## Rate Limiting and Throttling

```bash
# Rate limiting implementation
RATE_LIMIT_DIR="$LOG_DIR/rate_limits"
mkdir -p "$RATE_LIMIT_DIR"

check_rate_limit() {
    local key="$1"
    local max_count="$2"
    local window_seconds="$3"
    
    local count_file="$RATE_LIMIT_DIR/$key.count"
    local time_file="$RATE_LIMIT_DIR/$key.time"
    
    local current_time=$(date +%s)
    local last_time=0
    local count=0
    
    [ -f "$time_file" ] && last_time=$(cat "$time_file")
    [ -f "$count_file" ] && count=$(cat "$count_file")
    
    # Reset if window expired
    if [ $((current_time - last_time)) -gt "$window_seconds" ]; then
        count=0
        echo "$current_time" > "$time_file"
    fi
    
    # Check limit
    if [ "$count" -ge "$max_count" ]; then
        return 1  # Rate limit exceeded
    fi
    
    # Increment counter
    echo $((count + 1)) > "$count_file"
    return 0
}

# Example: Limit deployment triggers to 5 per hour
case "$EVENT_TYPE" in
    "push")
        if check_rate_limit "deploy_$REPO_NAME" 5 3600; then
            # Proceed with deployment
            log_event "Rate limit check passed, proceeding with deployment"
        else
            log_event "Rate limit exceeded for deployments, skipping"
        fi
        ;;
esac
```

## Integration Testing

```bash
# Test webhook locally
test_webhook_integration() {
    local test_event="$1"
    local test_payload="$2"
    
    # Create test payload
    local temp_payload=$(mktemp)
    echo "$test_payload" > "$temp_payload"
    
    # Execute handler directly
    GITHUB_REPO="test/repo" \
    GITHUB_EVENT_TYPE="$test_event" \
    ./handle-github-event.sh "test/repo" "$test_event" "test" "$(cat "$temp_payload")"
    
    # Clean up
    rm -f "$temp_payload"
}

# Run tests
echo "Testing push event..."
test_webhook_integration "push" '{
    "ref": "refs/heads/main",
    "pusher": {"name": "testuser"},
    "commits": [{"message": "Test commit"}]
}'

echo "Testing issue event..."
test_webhook_integration "issues" '{
    "action": "opened",
    "issue": {"number": 1, "title": "Test issue"}
}'
```

## Best Practices

1. **Async Processing**: Use `&` for long-running tasks
2. **Error Handling**: Always check command exit codes
3. **Logging**: Log both successes and failures
4. **Security**: Validate all inputs from webhook payloads
5. **Performance**: Use jq efficiently, cache parsed values
6. **Reliability**: Implement retries for external service calls
7. **Monitoring**: Export metrics for observability
8. **Testing**: Test all event handlers thoroughly