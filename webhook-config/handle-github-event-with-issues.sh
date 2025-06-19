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