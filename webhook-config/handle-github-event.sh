#!/bin/bash

# GitHub Webhook Handler Script
# Receives all GitHub events and processes them

# Arguments passed by webhook:
# $1 = repository.full_name
# $2 = X-GitHub-Event header
# $3 = action (if applicable)
# $4 = entire payload JSON

REPO_NAME="$1"
EVENT_TYPE="$2"
ACTION="$3"
PAYLOAD="$4"

# Log directory
LOG_DIR="/home/clide/promptforge/webhook-config/logs"
mkdir -p "$LOG_DIR"

# Log file with timestamp
LOG_FILE="$LOG_DIR/github-events-$(date +%Y%m%d).log"

# Function to log with timestamp
log_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Log the incoming event
log_event "Event received: $EVENT_TYPE for $REPO_NAME"
log_event "Action: $ACTION"

# Parse and log specific event details
case "$EVENT_TYPE" in
    "push")
        BRANCH=$(echo "$PAYLOAD" | jq -r '.ref' | sed 's|refs/heads/||')
        PUSHER=$(echo "$PAYLOAD" | jq -r '.pusher.name')
        COMMIT_COUNT=$(echo "$PAYLOAD" | jq -r '.commits | length')
        log_event "Push event: $PUSHER pushed $COMMIT_COUNT commits to $BRANCH"
        ;;
    
    "pull_request")
        PR_NUMBER=$(echo "$PAYLOAD" | jq -r '.pull_request.number')
        PR_TITLE=$(echo "$PAYLOAD" | jq -r '.pull_request.title')
        PR_USER=$(echo "$PAYLOAD" | jq -r '.pull_request.user.login')
        log_event "Pull Request #$PR_NUMBER: $ACTION by $PR_USER - $PR_TITLE"
        ;;
    
    "issues")
        ISSUE_NUMBER=$(echo "$PAYLOAD" | jq -r '.issue.number')
        ISSUE_TITLE=$(echo "$PAYLOAD" | jq -r '.issue.title')
        ISSUE_USER=$(echo "$PAYLOAD" | jq -r '.issue.user.login')
        log_event "Issue #$ISSUE_NUMBER: $ACTION by $ISSUE_USER - $ISSUE_TITLE"
        ;;
    
    "release")
        RELEASE_TAG=$(echo "$PAYLOAD" | jq -r '.release.tag_name')
        RELEASE_NAME=$(echo "$PAYLOAD" | jq -r '.release.name')
        log_event "Release $ACTION: $RELEASE_TAG - $RELEASE_NAME"
        ;;
    
    "workflow_run")
        WORKFLOW_NAME=$(echo "$PAYLOAD" | jq -r '.workflow_run.name')
        WORKFLOW_STATUS=$(echo "$PAYLOAD" | jq -r '.workflow_run.status')
        WORKFLOW_CONCLUSION=$(echo "$PAYLOAD" | jq -r '.workflow_run.conclusion')
        log_event "Workflow '$WORKFLOW_NAME': $WORKFLOW_STATUS (conclusion: $WORKFLOW_CONCLUSION)"
        ;;
    
    *)
        log_event "Other event type: $EVENT_TYPE with action: $ACTION"
        ;;
esac

# Save full payload for debugging (optional)
if [ "${SAVE_PAYLOADS:-false}" = "true" ]; then
    PAYLOAD_FILE="$LOG_DIR/payloads/$(date +%Y%m%d-%H%M%S)-$EVENT_TYPE-$ACTION.json"
    mkdir -p "$LOG_DIR/payloads"
    echo "$PAYLOAD" | jq '.' > "$PAYLOAD_FILE" 2>/dev/null || echo "$PAYLOAD" > "$PAYLOAD_FILE"
    log_event "Payload saved to: $PAYLOAD_FILE"
fi

# Custom actions based on events
# Add your custom logic here

# Example: On push to main, trigger a build
if [ "$EVENT_TYPE" = "push" ] && [ "$BRANCH" = "main" ]; then
    log_event "Main branch updated - triggering build..."
    # cd /home/clide/promptforge && npm run build >> "$LOG_FILE" 2>&1
fi

# Example: On new release, deploy
if [ "$EVENT_TYPE" = "release" ] && [ "$ACTION" = "published" ]; then
    log_event "New release published - triggering deployment..."
    # ./deploy.sh "$RELEASE_TAG" >> "$LOG_FILE" 2>&1
fi

log_event "Event processing completed"
exit 0