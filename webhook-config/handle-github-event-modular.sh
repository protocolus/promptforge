#!/bin/bash

# GitHub Webhook Handler Script with Modular Prompt System
# Loads prompts from separate files for different event types

# Arguments passed by webhook:
# $1 = repository.full_name
# $2 = X-GitHub-Event header
# $3 = action (if applicable)
# $4 = entire payload JSON

REPO_NAME="$1"
EVENT_TYPE="$2"
ACTION="$3"
PAYLOAD="$4"

# Base directory for prompts
PROMPT_DIR="/home/clide/promptforge/webhook-config/prompts"

# Log directory
LOG_DIR="/home/clide/promptforge/webhook-config/logs"
mkdir -p "$LOG_DIR"

# Log file with timestamp
LOG_FILE="$LOG_DIR/github-events-$(date +%Y%m%d).log"

# Function to log with timestamp
log_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Function to load prompt from file
load_prompt() {
    local prompt_file="$1"
    if [ -f "$prompt_file" ]; then
        cat "$prompt_file"
    else
        log_event "ERROR: Prompt file not found: $prompt_file"
        echo "Error: Prompt configuration not found for this event type."
        return 1
    fi
}

# Function to process events with Claude
process_with_claude() {
    local event_type=$1
    local event_data=$2
    local prompt_file=$3
    local output_file=$4
    
    log_event "Processing $event_type with Claude Code using prompt: $prompt_file"
    
    # Load the prompt
    local prompt=$(load_prompt "$prompt_file")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Create the analysis request
    local temp_file=$(mktemp)
    cat > "$temp_file" << EOF
# GitHub Event Analysis Request

## Event Details
$event_data

## Analysis Request
$prompt
EOF
    
    # Run Claude analysis
    log_event "Running claude -p analysis..."
    
    if claude -p < "$temp_file" > "$output_file" 2>&1; then
        log_event "Analysis completed successfully"
        rm -f "$temp_file"
        return 0
    else
        log_event "ERROR: Claude analysis failed"
        rm -f "$temp_file"
        return 1
    fi
}

# Function to process new issues
process_new_issue() {
    local issue_number=$1
    local issue_title=$2
    local issue_body=$3
    local issue_user=$4
    local issue_url="https://github.com/${REPO_NAME}/issues/${issue_number}"
    
    log_event "Processing new issue #${issue_number}"
    
    # Prepare event data
    local event_data="- **Repository**: ${REPO_NAME}
- **Issue Number**: #${issue_number}
- **Title**: ${issue_title}
- **URL**: ${issue_url}
- **Author**: ${issue_user}

## Issue Description
${issue_body}"
    
    # Create output directory
    mkdir -p /home/clide/promptforge/issues
    
    # Process with Claude
    local output_file="/home/clide/promptforge/issues/issue_${issue_number}_analysis.md"
    local prompt_file="${PROMPT_DIR}/issues/new_issue.md"
    
    if process_with_claude "issue" "$event_data" "$prompt_file" "$output_file"; then
        # Apply suggested labels
        apply_suggested_labels "$issue_number" "$output_file"
        
        # Post analysis comment
        post_analysis_comment "$issue_number" "$output_file" "issue"
        
        # Check if issue should be closed
        check_and_close_if_needed "$issue_number" "$output_file"
        
        # Mark as analyzed
        gh issue edit "$issue_number" --repo "$REPO_NAME" --add-label "clide-analyzed" 2>/dev/null
    fi
}

# Function to process new pull requests
process_new_pr() {
    local pr_number=$1
    local pr_title=$2
    local pr_body=$3
    local pr_user=$4
    local pr_url="https://github.com/${REPO_NAME}/pull/${pr_number}"
    
    log_event "Processing new PR #${pr_number}"
    
    # Get PR diff
    local pr_diff=$(gh pr diff "$pr_number" --repo "$REPO_NAME" 2>/dev/null | head -1000)
    
    # Prepare event data
    local event_data="- **Repository**: ${REPO_NAME}
- **PR Number**: #${pr_number}
- **Title**: ${pr_title}
- **URL**: ${pr_url}
- **Author**: ${pr_user}

## PR Description
${pr_body}

## Code Changes Preview
\`\`\`diff
${pr_diff}
\`\`\`"
    
    # Create output directory
    mkdir -p /home/clide/promptforge/pull_requests
    
    # Process with Claude
    local output_file="/home/clide/promptforge/pull_requests/pr_${pr_number}_analysis.md"
    local prompt_file="${PROMPT_DIR}/pull_requests/new_pr.md"
    
    if process_with_claude "pull_request" "$event_data" "$prompt_file" "$output_file"; then
        # Post analysis comment
        post_analysis_comment "$pr_number" "$output_file" "pr"
        
        # Apply suggested labels
        apply_pr_labels "$pr_number" "$output_file"
    fi
}

# Function to process review requests
process_review_request() {
    local pr_number=$1
    local reviewer=$2
    local requester=$3
    
    log_event "Processing review request for PR #${pr_number}"
    
    # Get PR details
    local pr_data=$(gh pr view "$pr_number" --repo "$REPO_NAME" --json title,body,author,files)
    local pr_title=$(echo "$pr_data" | jq -r '.title')
    local pr_body=$(echo "$pr_data" | jq -r '.body')
    local pr_author=$(echo "$pr_data" | jq -r '.author.login')
    local pr_files=$(echo "$pr_data" | jq -r '.files[].path' | head -20)
    
    # Get PR diff
    local pr_diff=$(gh pr diff "$pr_number" --repo "$REPO_NAME" 2>/dev/null | head -2000)
    
    # Prepare event data
    local event_data="- **Repository**: ${REPO_NAME}
- **PR Number**: #${pr_number}
- **Title**: ${pr_title}
- **Author**: ${pr_author}
- **Reviewer Requested**: ${reviewer}
- **Requested By**: ${requester}

## PR Description
${pr_body}

## Modified Files
${pr_files}

## Code Changes
\`\`\`diff
${pr_diff}
\`\`\`"
    
    # Create output directory
    mkdir -p /home/clide/promptforge/reviews
    
    # Process with Claude
    local output_file="/home/clide/promptforge/reviews/pr_${pr_number}_review_$(date +%s).md"
    local prompt_file="${PROMPT_DIR}/reviews/pr_review_requested.md"
    
    if process_with_claude "review_request" "$event_data" "$prompt_file" "$output_file"; then
        # Post review comment
        post_analysis_comment "$pr_number" "$output_file" "review"
    fi
}

# Function to process workflow failures
process_workflow_failure() {
    local workflow_name=$1
    local workflow_run_id=$2
    local workflow_conclusion=$3
    
    log_event "Processing failed workflow: ${workflow_name}"
    
    # Get workflow run details
    local run_data=$(gh api "repos/${REPO_NAME}/actions/runs/${workflow_run_id}" 2>/dev/null)
    local commit_sha=$(echo "$run_data" | jq -r '.head_sha')
    local commit_message=$(echo "$run_data" | jq -r '.head_commit.message')
    
    # Get failed jobs
    local failed_jobs=$(gh api "repos/${REPO_NAME}/actions/runs/${workflow_run_id}/jobs" | jq -r '.jobs[] | select(.conclusion=="failure") | .name')
    
    # Prepare event data
    local event_data="- **Repository**: ${REPO_NAME}
- **Workflow**: ${workflow_name}
- **Run ID**: ${workflow_run_id}
- **Conclusion**: ${workflow_conclusion}
- **Commit**: ${commit_sha}
- **Commit Message**: ${commit_message}

## Failed Jobs
${failed_jobs}

## Workflow URL
https://github.com/${REPO_NAME}/actions/runs/${workflow_run_id}"
    
    # Create output directory
    mkdir -p /home/clide/promptforge/workflows
    
    # Process with Claude
    local output_file="/home/clide/promptforge/workflows/workflow_${workflow_run_id}_analysis.md"
    local prompt_file="${PROMPT_DIR}/workflows/workflow_failed.md"
    
    if process_with_claude "workflow_failure" "$event_data" "$prompt_file" "$output_file"; then
        # Post analysis as issue comment if related to PR
        local pr_number=$(echo "$run_data" | jq -r '.pull_requests[0].number // empty')
        if [ -n "$pr_number" ]; then
            post_analysis_comment "$pr_number" "$output_file" "workflow"
        fi
    fi
}

# Function to apply suggested labels for issues
apply_suggested_labels() {
    local issue_number=$1
    local analysis_file=$2
    
    log_event "Parsing analysis to extract suggested labels..."
    
    # Extract labels from analysis
    local labels=$(grep -E "(bug|enhancement|question|documentation|maintenance|priority-|difficulty-|component-)" "$analysis_file" | 
                   grep -oE "(bug|enhancement|question|documentation|maintenance|priority-(high|medium|low)|difficulty-(easy|moderate|complex)|component-(frontend|backend|database))" |
                   sort -u)
    
    for label in $labels; do
        gh issue edit "$issue_number" --repo "$REPO_NAME" --add-label "$label" 2>/dev/null && 
        log_event "Applied label: $label" ||
        log_event "Could not apply label: $label"
        sleep 1
    done
}

# Function to apply PR labels
apply_pr_labels() {
    local pr_number=$1
    local analysis_file=$2
    
    log_event "Applying PR labels..."
    
    # Extract size and type labels
    local labels=$(grep -E "(small|medium|large|bug-fix|feature|refactor|docs|needs-review|needs-changes|approved)" "$analysis_file" |
                   grep -oE "(size/(small|medium|large)|type/(bug-fix|feature|refactor|docs)|status/(needs-review|needs-changes|approved))" |
                   sort -u)
    
    for label in $labels; do
        gh pr edit "$pr_number" --repo "$REPO_NAME" --add-label "$label" 2>/dev/null &&
        log_event "Applied PR label: $label" ||
        log_event "Could not apply PR label: $label"
        sleep 1
    done
}

# Function to post analysis comment
post_analysis_comment() {
    local number=$1
    local analysis_file=$2
    local type=$3
    
    log_event "Posting analysis comment..."
    
    # Determine emoji and title based on type
    local emoji title
    case "$type" in
        "issue") emoji="🤖"; title="Automated Issue Analysis" ;;
        "pr") emoji="🔍"; title="Automated PR Review" ;;
        "review") emoji="👁️"; title="Automated Code Review" ;;
        "workflow") emoji="⚠️"; title="Workflow Failure Analysis" ;;
        *) emoji="📋"; title="Automated Analysis" ;;
    esac
    
    local temp_comment=$(mktemp)
    cat > "$temp_comment" << EOF
## $emoji $title

Hi! I've automatically analyzed this using Claude Code. Here's my assessment:

---

$(cat "$analysis_file")

---

*This analysis was generated automatically by the PromptForge webhook system. The suggestions above are AI-generated and should be reviewed by a human maintainer.*

*Analysis completed at: $(date '+%Y-%m-%d %H:%M:%S UTC')*
EOF
    
    # Post comment based on type
    if [ "$type" = "pr" ] || [ "$type" = "review" ] || [ "$type" = "workflow" ]; then
        gh pr comment "$number" --repo "$REPO_NAME" --body-file "$temp_comment" 2>/dev/null &&
        log_event "Posted comment on PR #${number}" ||
        log_event "Failed to post comment on PR #${number}"
    else
        gh issue comment "$number" --repo "$REPO_NAME" --body-file "$temp_comment" 2>/dev/null &&
        log_event "Posted comment on issue #${number}" ||
        log_event "Failed to post comment on issue #${number}"
    fi
    
    rm -f "$temp_comment"
}

# Function to check and close non-viable issues
check_and_close_if_needed() {
    local issue_number=$1
    local analysis_file=$2
    
    if grep -q "RECOMMENDATION: CLOSE ISSUE" "$analysis_file"; then
        log_event "Claude recommends closing issue #${issue_number}"
        
        local close_message=$(mktemp)
        cat > "$close_message" << EOF
## Issue Closed by Automated Analysis

This issue has been automatically closed based on the analysis above.

If you believe this was closed in error, please feel free to provide additional context and request that a maintainer review the decision.

Thank you for your interest in the project!
EOF
        
        gh issue comment "$issue_number" --repo "$REPO_NAME" --body-file "$close_message" 2>/dev/null
        gh issue close "$issue_number" --repo "$REPO_NAME" --reason "not planned" 2>/dev/null &&
        log_event "Closed issue #${issue_number}" ||
        log_event "Failed to close issue #${issue_number}"
        
        rm -f "$close_message"
    fi
}

# Main event processing logic
log_event "Event received: $EVENT_TYPE for $REPO_NAME (action: $ACTION)"

case "$EVENT_TYPE" in
    "issues")
        ISSUE_NUMBER=$(echo "$PAYLOAD" | jq -r '.issue.number')
        ISSUE_TITLE=$(echo "$PAYLOAD" | jq -r '.issue.title')
        ISSUE_USER=$(echo "$PAYLOAD" | jq -r '.issue.user.login')
        ISSUE_BODY=$(echo "$PAYLOAD" | jq -r '.issue.body // ""')
        
        if [ "$ACTION" = "opened" ]; then
            # Check if already analyzed
            LABELS=$(echo "$PAYLOAD" | jq -r '.issue.labels[].name' | grep -c "clide-analyzed" || true)
            if [ "$LABELS" -eq 0 ]; then
                process_new_issue "$ISSUE_NUMBER" "$ISSUE_TITLE" "$ISSUE_BODY" "$ISSUE_USER"
            fi
        fi
        ;;
    
    "pull_request")
        PR_NUMBER=$(echo "$PAYLOAD" | jq -r '.pull_request.number')
        PR_TITLE=$(echo "$PAYLOAD" | jq -r '.pull_request.title')
        PR_USER=$(echo "$PAYLOAD" | jq -r '.pull_request.user.login')
        PR_BODY=$(echo "$PAYLOAD" | jq -r '.pull_request.body // ""')
        
        case "$ACTION" in
            "opened")
                process_new_pr "$PR_NUMBER" "$PR_TITLE" "$PR_BODY" "$PR_USER"
                ;;
            "synchronize")
                # PR was updated with new commits
                log_event "PR #${PR_NUMBER} updated - could trigger re-review"
                # Uncomment to enable:
                # process_pr_update "$PR_NUMBER" "$PR_TITLE" "$PR_BODY" "$PR_USER"
                ;;
        esac
        ;;
    
    "pull_request_review")
        if [ "$ACTION" = "submitted" ]; then
            PR_NUMBER=$(echo "$PAYLOAD" | jq -r '.pull_request.number')
            REVIEW_STATE=$(echo "$PAYLOAD" | jq -r '.review.state')
            REVIEWER=$(echo "$PAYLOAD" | jq -r '.review.user.login')
            log_event "Review submitted on PR #${PR_NUMBER} by ${REVIEWER}: ${REVIEW_STATE}"
        fi
        ;;
    
    "pull_request_review_requested")
        PR_NUMBER=$(echo "$PAYLOAD" | jq -r '.pull_request.number')
        REVIEWER=$(echo "$PAYLOAD" | jq -r '.requested_reviewer.login // .requested_team.name // "unknown"')
        REQUESTER=$(echo "$PAYLOAD" | jq -r '.sender.login')
        
        log_event "Review requested on PR #${PR_NUMBER} from ${REVIEWER} by ${REQUESTER}"
        process_review_request "$PR_NUMBER" "$REVIEWER" "$REQUESTER"
        ;;
    
    "workflow_run")
        WORKFLOW_NAME=$(echo "$PAYLOAD" | jq -r '.workflow_run.name')
        WORKFLOW_STATUS=$(echo "$PAYLOAD" | jq -r '.workflow_run.status')
        WORKFLOW_CONCLUSION=$(echo "$PAYLOAD" | jq -r '.workflow_run.conclusion // "null"')
        WORKFLOW_RUN_ID=$(echo "$PAYLOAD" | jq -r '.workflow_run.id')
        
        if [ "$ACTION" = "completed" ] && [ "$WORKFLOW_CONCLUSION" = "failure" ]; then
            process_workflow_failure "$WORKFLOW_NAME" "$WORKFLOW_RUN_ID" "$WORKFLOW_CONCLUSION"
        fi
        ;;
    
    "release")
        RELEASE_TAG=$(echo "$PAYLOAD" | jq -r '.release.tag_name')
        RELEASE_NAME=$(echo "$PAYLOAD" | jq -r '.release.name')
        log_event "Release $ACTION: $RELEASE_TAG - $RELEASE_NAME"
        
        if [ "$ACTION" = "published" ]; then
            # Could process new releases
            log_event "New release published: $RELEASE_TAG"
        fi
        ;;
    
    "push")
        BRANCH=$(echo "$PAYLOAD" | jq -r '.ref' | sed 's|refs/heads/||')
        PUSHER=$(echo "$PAYLOAD" | jq -r '.pusher.name')
        COMMIT_COUNT=$(echo "$PAYLOAD" | jq -r '.commits | length')
        log_event "Push event: $PUSHER pushed $COMMIT_COUNT commits to $BRANCH"
        ;;
    
    *)
        log_event "Unhandled event type: $EVENT_TYPE with action: $ACTION"
        ;;
esac

# Save payload for debugging if enabled
if [ "${SAVE_PAYLOADS:-false}" = "true" ]; then
    PAYLOAD_FILE="$LOG_DIR/payloads/$(date +%Y%m%d-%H%M%S)-$EVENT_TYPE-$ACTION.json"
    mkdir -p "$LOG_DIR/payloads"
    echo "$PAYLOAD" | jq '.' > "$PAYLOAD_FILE" 2>/dev/null || echo "$PAYLOAD" > "$PAYLOAD_FILE"
    log_event "Payload saved to: $PAYLOAD_FILE"
fi

log_event "Event processing completed"
exit 0