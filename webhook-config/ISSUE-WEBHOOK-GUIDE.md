# GitHub Issue Webhook Integration Guide

This guide documents how to configure GitHub webhooks to automatically analyze new issues using Claude Code, replacing the polling-based approach with real-time event-driven processing.

## Overview

Instead of polling GitHub every 20 seconds for new issues, webhooks provide instant notifications when issues are created. This approach is:
- **More efficient**: No constant API calls checking for changes
- **Faster response**: Immediate processing when issues are created
- **More reliable**: No missed issues due to polling intervals
- **Better for rate limits**: Reduces GitHub API usage significantly

## Architecture Comparison

### Polling Approach (issue_watcher.sh)
```
┌─────────────┐
│   GitHub    │
└──────┬──────┘
       │ Poll every 20s
       ▼
┌─────────────┐
│issue_watcher│───► Check for issues without "clide-analyzed" label
└──────┬──────┘
       │ If new issue found
       ▼
┌─────────────┐
│ claude -p   │───► Analyze issue
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   GitHub    │───► Post comment, apply labels, mark analyzed
└─────────────┘
```

### Webhook Approach
```
┌─────────────┐
│   GitHub    │───► Issue created
└──────┬──────┘
       │ Instant webhook
       ▼
┌─────────────┐
│   Webhook   │───► Validate signature
│   Service   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│Event Handler│───► Process issue
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ claude -p   │───► Analyze issue
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   GitHub    │───► Post comment, apply labels
└─────────────┘
```

## Modified Event Handler for Issues

The webhook handler needs to be updated to process new issues. Here's the enhanced `handle-github-event.sh`:

```bash
#!/bin/bash

# GitHub Webhook Handler Script
# Enhanced to process new issues with Claude Code analysis

# Arguments passed by webhook:
# $1 = repository.full_name
# $2 = X-GitHub-Event header
# $3 = action (if applicable)
# $4 = entire payload JSON

REPO_NAME="$1"
EVENT_TYPE="$2"
ACTION="$3"
PAYLOAD="$4"

# Configuration
CLAUDE_PROMPT="Please analyze this GitHub issue and perform the following tasks:

## STEP 0: Viability Check
First, determine if this issue represents a sensible and constructive request:
- Is the request technically feasible and aligned with the project's goals?
- Does it represent a legitimate bug, enhancement, or question?
- Is it spam, nonsensical, harmful, or a bad idea for the project?

If the issue is NOT viable (spam, nonsensical, harmful, or a bad idea):
- Clearly state: **RECOMMENDATION: CLOSE ISSUE**
- Explain why this issue should be closed
- Suggest the 'wontfix' or 'invalid' label as appropriate
- Be polite but firm in the explanation

If the issue IS viable, continue with the full analysis:

## STEP 1: Issue Classification
Classify this issue into one of these categories:
- bug: Software defect or error that needs fixing
- enhancement: New feature or improvement request
- question: Question or help request
- documentation: Documentation improvement needed
- maintenance: Code cleanup, refactoring, or maintenance task

## STEP 2: GitHub Labeling
Based on your classification, suggest appropriate GitHub labels that should be added to this issue. Consider:
- Issue type (bug, enhancement, question, documentation, maintenance)
- Priority level (high, medium, low)
- Complexity (easy, moderate, complex)
- Component affected (frontend, backend, database, etc.)
- Special labels (wontfix, invalid) if the issue should be closed

## STEP 3: Detailed Analysis
Provide:
1. **Issue Summary**: Brief description of what this issue is about
2. **Impact Assessment**: How this affects users or the system
3. **Priority Justification**: Why you assigned this priority level
4. **Complexity Estimate**: Technical difficulty and time investment

## STEP 4: Implementation Plan
Create a detailed plan with:
1. **Prerequisites**: What needs to be done first
2. **Step-by-step approach**: Numbered list of implementation steps
3. **Files likely to be modified**: List of files that may need changes
4. **Testing strategy**: How to verify the solution works
5. **Potential risks**: What could go wrong during implementation

## STEP 5: Questions and Clarifications
List any questions that need clarification from the issue author before work can begin.

Please format your response in clear markdown sections."

# Log directory
LOG_DIR="/home/clide/promptforge/webhook-config/logs"
mkdir -p "$LOG_DIR"

# Log file with timestamp
LOG_FILE="$LOG_DIR/github-events-$(date +%Y%m%d).log"

# Function to log with timestamp
log_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Function to process a new issue with Claude
process_new_issue() {
    local issue_number=$1
    local issue_title=$2
    local issue_body=$3
    local issue_user=$4
    local issue_url="https://github.com/${REPO_NAME}/issues/${issue_number}"
    
    log_event "Processing new issue #${issue_number} with Claude Code"
    
    # Create issues directory if it doesn't exist
    mkdir -p /home/clide/promptforge/issues
    
    # Create the analysis prompt file
    local temp_file=$(mktemp)
    cat > "$temp_file" << EOF
# GitHub Issue Analysis Request

## Issue Details
- **Repository**: ${REPO_NAME}
- **Issue Number**: #${issue_number}
- **Title**: ${issue_title}
- **URL**: ${issue_url}
- **Author**: ${issue_user}

## Issue Description
${issue_body}

## Analysis Request
${CLAUDE_PROMPT}
EOF
    
    # Run Claude analysis
    log_event "Running claude -p analysis for issue #${issue_number}..."
    
    if claude -p < "$temp_file" > "/home/clide/promptforge/issues/issue_${issue_number}_analysis.md" 2>&1; then
        log_event "Analysis completed for issue #${issue_number}"
        
        # Apply suggested labels
        apply_suggested_labels "$issue_number" "/home/clide/promptforge/issues/issue_${issue_number}_analysis.md"
        
        # Post analysis comment
        post_analysis_comment "$issue_number" "/home/clide/promptforge/issues/issue_${issue_number}_analysis.md"
        
        # Check if issue should be closed
        check_and_close_if_needed "$issue_number" "/home/clide/promptforge/issues/issue_${issue_number}_analysis.md"
        
        # Mark as analyzed
        if gh issue edit "$issue_number" --repo "$REPO_NAME" --add-label "clide-analyzed" 2>/dev/null; then
            log_event "Marked issue #${issue_number} as analyzed"
        else
            log_event "Could not add clide-analyzed label to issue #${issue_number}"
        fi
    else
        log_event "ERROR: Failed to analyze issue #${issue_number}"
    fi
    
    # Clean up
    rm -f "$temp_file"
}

# Function to apply suggested labels (same as in polling script)
apply_suggested_labels() {
    local issue_number=$1
    local analysis_file=$2
    
    log_event "Parsing analysis to extract suggested labels for issue #${issue_number}..."
    
    local suggested_labels=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ "## STEP 2: GitHub Labeling" ]]; then
            continue
        fi
        
        if [[ "$line" =~ bug|enhancement|question|documentation|maintenance|high|medium|low|easy|moderate|complex|frontend|backend|database ]]; then
            for word in $line; do
                case "$word" in
                    *bug*) suggested_labels="$suggested_labels bug" ;;
                    *enhancement*) suggested_labels="$suggested_labels enhancement" ;;
                    *question*) suggested_labels="$suggested_labels question" ;;
                    *documentation*) suggested_labels="$suggested_labels documentation" ;;
                    *maintenance*) suggested_labels="$suggested_labels maintenance" ;;
                    *high*) suggested_labels="$suggested_labels priority-high" ;;
                    *medium*) suggested_labels="$suggested_labels priority-medium" ;;
                    *low*) suggested_labels="$suggested_labels priority-low" ;;
                    *easy*) suggested_labels="$suggested_labels difficulty-easy" ;;
                    *moderate*) suggested_labels="$suggested_labels difficulty-moderate" ;;
                    *complex*) suggested_labels="$suggested_labels difficulty-complex" ;;
                    *frontend*) suggested_labels="$suggested_labels component-frontend" ;;
                    *backend*) suggested_labels="$suggested_labels component-backend" ;;
                    *database*) suggested_labels="$suggested_labels component-database" ;;
                esac
            done
        fi
    done < "$analysis_file"
    
    suggested_labels=$(echo "$suggested_labels" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    
    if [[ -n "$suggested_labels" ]]; then
        log_event "Applying suggested labels: $suggested_labels"
        
        for label in $suggested_labels; do
            if gh issue edit "$issue_number" --repo "$REPO_NAME" --add-label "$label" 2>/dev/null; then
                log_event "Applied label: $label"
            else
                log_event "Could not apply label: $label"
            fi
            sleep 1
        done
    fi
}

# Function to post analysis comment (same as in polling script)
post_analysis_comment() {
    local issue_number=$1
    local analysis_file=$2
    
    log_event "Posting analysis as comment on issue #${issue_number}..."
    
    local temp_comment=$(mktemp)
    cat > "$temp_comment" << EOF
## 🤖 Automated Issue Analysis

Hi! I've automatically analyzed this issue using Claude Code. Here's my assessment:

---

$(cat "$analysis_file")

---

*This analysis was generated automatically by the PromptForge issue webhook. The suggestions above are AI-generated and should be reviewed by a human maintainer.*

*Issue analyzed at: $(date '+%Y-%m-%d %H:%M:%S UTC')*
EOF
    
    if gh issue comment "$issue_number" --repo "$REPO_NAME" --body-file "$temp_comment" 2>/dev/null; then
        log_event "Posted analysis comment on issue #${issue_number}"
    else
        log_event "ERROR: Failed to post comment on issue #${issue_number}"
    fi
    
    rm -f "$temp_comment"
}

# Function to check and close if needed (same as in polling script)
check_and_close_if_needed() {
    local issue_number=$1
    local analysis_file=$2
    
    if grep -q "RECOMMENDATION: CLOSE ISSUE" "$analysis_file"; then
        log_event "Claude recommends closing issue #${issue_number} as not viable"
        
        local close_message=$(mktemp)
        cat > "$close_message" << EOF
## Issue Closed by Automated Analysis

This issue has been automatically closed based on the analysis above.

**Reason**: The automated analysis determined that this issue is not viable for implementation.

If you believe this was closed in error, please feel free to:
1. Provide additional context or clarification
2. Explain why this would benefit the project
3. Request that a maintainer review the decision

Thank you for your interest in PromptForge!

---
*This action was performed automatically by the PromptForge issue analyzer.*
EOF
        
        if gh issue comment "$issue_number" --repo "$REPO_NAME" --body-file "$close_message" 2>/dev/null; then
            log_event "Posted closing explanation on issue #${issue_number}"
        fi
        
        if gh issue close "$issue_number" --repo "$REPO_NAME" --reason "not planned" 2>/dev/null; then
            log_event "Closed issue #${issue_number} as not viable"
        else
            log_event "ERROR: Failed to close issue #${issue_number}"
        fi
        
        rm -f "$close_message"
    fi
}

# Log the incoming event
log_event "Event received: $EVENT_TYPE for $REPO_NAME"
log_event "Action: $ACTION"

# Parse and process specific events
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
        ISSUE_BODY=$(echo "$PAYLOAD" | jq -r '.issue.body')
        
        log_event "Issue #$ISSUE_NUMBER: $ACTION by $ISSUE_USER - $ISSUE_TITLE"
        
        # Process new issues
        if [ "$ACTION" = "opened" ]; then
            log_event "New issue detected - initiating Claude Code analysis"
            
            # Check if already analyzed (in case of duplicate webhooks)
            LABELS=$(echo "$PAYLOAD" | jq -r '.issue.labels[].name' | grep -c "clide-analyzed" || true)
            if [ "$LABELS" -eq 0 ]; then
                process_new_issue "$ISSUE_NUMBER" "$ISSUE_TITLE" "$ISSUE_BODY" "$ISSUE_USER"
            else
                log_event "Issue #$ISSUE_NUMBER already has clide-analyzed label, skipping"
            fi
        fi
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

log_event "Event processing completed"
exit 0
```

## Setup Instructions

### Prerequisites
1. Webhook service already running (from WEBHOOK-SETUP-GUIDE.md)
2. GitHub CLI authenticated: `gh auth login`
3. Claude CLI installed and working: `claude -p`
4. Required labels created in repository (run `setup_github_labels.sh`)

### Step 1: Update the Event Handler

Replace the existing `handle-github-event.sh` with the enhanced version above that includes issue processing:

```bash
cd /home/clide/promptforge/webhook-config
# Backup existing handler
cp handle-github-event.sh handle-github-event.sh.bak
# Update with new version (copy the enhanced script above)
```

### Step 2: Configure Webhook for Issues

Option A: Using GitHub CLI
```bash
# List existing webhooks
gh api repos/protocolus/promptforge/hooks

# Update webhook to ensure issues events are included
gh api -X PATCH repos/protocolus/promptforge/hooks/[WEBHOOK_ID] \
  -f events[]="issues" \
  -f events[]="push" \
  -f events[]="pull_request" \
  -f events[]="release"
```

Option B: GitHub Web Interface
1. Go to https://github.com/protocolus/promptforge/settings/hooks
2. Click on your webhook
3. Under "Which events would you like to trigger this webhook?"
4. Ensure "Issues" is checked
5. Save changes

### Step 3: Restart Webhook Service

```bash
# Find webhook process
ps aux | grep webhook

# Kill existing process
kill [PID]

# Start fresh
./start-webhook.sh
```

### Step 4: Verify Setup

```bash
# Monitor logs
tail -f logs/github-events-*.log

# Create a test issue in your repository
# Watch for:
# - Webhook receipt log
# - Claude analysis starting
# - Analysis completion
# - Comment posting
# - Label application
```

## Testing the Issue Webhook

### Manual Test
1. Create a test issue in your repository:
   ```bash
   gh issue create --repo protocolus/promptforge \
     --title "Test webhook integration" \
     --body "This is a test issue to verify webhook processing"
   ```

2. Monitor the logs:
   ```bash
   tail -f webhook-config/logs/github-events-*.log
   ```

3. Check for:
   - Issue creation event logged
   - Claude analysis started
   - Analysis file created in `issues/`
   - Comment posted on GitHub
   - Labels applied
   - "clide-analyzed" label added

### Automated Test Script

Create `test-issue-webhook.sh`:

```bash
#!/bin/bash

echo "Testing GitHub Issue Webhook Integration"

# Create test issue
ISSUE_NUMBER=$(gh issue create --repo protocolus/promptforge \
  --title "Webhook Test: $(date +%s)" \
  --body "Automated test issue for webhook verification" \
  --label "test" | grep -o '[0-9]*$')

echo "Created test issue #$ISSUE_NUMBER"
echo "Waiting for webhook processing..."

# Wait for processing
sleep 30

# Check if analyzed
if gh issue view $ISSUE_NUMBER --repo protocolus/promptforge --json labels | grep -q "clide-analyzed"; then
    echo "✓ Issue was analyzed successfully"
else
    echo "✗ Issue was not analyzed"
fi

# Check for comment
COMMENT_COUNT=$(gh issue view $ISSUE_NUMBER --repo protocolus/promptforge --json comments --jq '.comments | length')
if [ "$COMMENT_COUNT" -gt 0 ]; then
    echo "✓ Analysis comment posted"
else
    echo "✗ No analysis comment found"
fi

# Clean up
read -p "Delete test issue? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    gh issue close $ISSUE_NUMBER --repo protocolus/promptforge
    echo "Test issue closed"
fi
```

## Comparison: Webhook vs Polling

### Advantages of Webhooks
1. **Instant Processing**: Issues analyzed immediately upon creation
2. **Efficient**: No wasted API calls checking for changes
3. **Reliable**: No missed issues between polling intervals
4. **Scalable**: Handles high issue volume without delays
5. **Rate Limit Friendly**: Minimal API usage

### Advantages of Polling
1. **Simple Setup**: No webhook infrastructure needed
2. **Works Anywhere**: Can run on any machine with internet
3. **Easy Recovery**: Can catch up on missed issues
4. **No Public Endpoint**: Doesn't require accessible webhook URL

### When to Use Each

**Use Webhooks when:**
- You have a stable server with public HTTPS endpoint
- You need real-time processing
- You process high volumes of issues
- You want minimal API usage

**Use Polling when:**
- You're running on a local machine
- You don't have a public endpoint
- You need a simple, portable solution
- You're doing development/testing

## Troubleshooting

### Issue Not Being Analyzed
1. Check webhook is receiving events:
   ```bash
   tail -f logs/webhook-service.log
   ```

2. Verify issue events are enabled:
   ```bash
   gh api repos/protocolus/promptforge/hooks/[WEBHOOK_ID]
   ```

3. Check Claude CLI is working:
   ```bash
   echo "test" | claude -p
   ```

### Labels Not Being Applied
1. Ensure labels exist in repository:
   ```bash
   gh label list --repo protocolus/promptforge
   ```

2. Run label setup if needed:
   ```bash
   ./setup_github_labels.sh protocolus/promptforge
   ```

### Analysis Not Posted as Comment
1. Check GitHub CLI authentication:
   ```bash
   gh auth status
   ```

2. Verify permissions:
   ```bash
   gh api user
   ```

## Monitoring and Maintenance

### Log Rotation
The webhook logs can grow large. Set up rotation:

```bash
# Add to /etc/logrotate.d/promptforge-webhook
/home/clide/promptforge/webhook-config/logs/*.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
    create 0644 clide clide
}
```

### Health Monitoring
Create a simple monitor script:

```bash
#!/bin/bash
# monitor-issue-webhook.sh

# Check webhook service
if ! pgrep -f webhook > /dev/null; then
    echo "WARNING: Webhook service not running"
    ./start-webhook.sh
fi

# Check recent activity
RECENT=$(find logs -name "github-events-*.log" -mmin -60 -exec grep -l "issues" {} \; | wc -l)
if [ "$RECENT" -eq 0 ]; then
    echo "WARNING: No issue events in last hour"
fi

# Check disk space for logs
USAGE=$(df -h logs | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$USAGE" -gt 80 ]; then
    echo "WARNING: Log directory over 80% full"
fi
```

## Security Considerations

1. **Webhook Secret**: Always use a strong secret in `hooks.json`
2. **Signature Validation**: Never disable HMAC validation
3. **Rate Limiting**: Consider adding rate limits to prevent abuse
4. **Access Control**: Restrict webhook endpoint to GitHub IPs only
5. **Log Sanitization**: Don't log sensitive issue content

## Conclusion

The webhook approach provides a more efficient and responsive way to analyze GitHub issues compared to polling. While it requires more initial setup, the benefits in terms of performance, reliability, and API usage make it the preferred solution for production environments.

For development or simple setups, the polling script remains a valid option that's easier to get started with.