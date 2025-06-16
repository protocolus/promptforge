#!/bin/bash
# issue_watcher.sh - Watches for new GitHub issues and runs Claude Code analysis
# 
# This script continuously monitors the GitHub repository for new issues that haven't
# been analyzed yet, then runs Claude Code (via 'clide' alias) to analyze each issue.
# 
# The script will:
# 1. Check for issues without the "claude-analyzed" label every 60 seconds
# 2. For each new issue, create a detailed analysis prompt
# 3. Run clide (Claude Code) to analyze the issue
# 4. Save the analysis output to a markdown file
# 5. Mark the issue as analyzed to prevent re-processing

# Configuration - the GitHub repository to monitor
REPO="protocolus/promptforge"

# The prompt template that will be sent to Claude Code for issue analysis
CLAUDE_PROMPT="Please analyze this GitHub issue and perform the following tasks:

## STEP 1: Issue Classification
First, classify this issue into one of these categories:
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

# Color codes for pretty terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_message() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Function to check if all required tools are installed and configured
check_dependencies() {
    # Check if GitHub CLI is installed
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed"
        exit 1
    fi
    
    # Check if jq JSON processor is installed
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed"
        exit 1
    fi
    
    # Check if claude CLI is available
    if ! command -v claude &> /dev/null; then
        log_error "claude CLI is not available"
        log_error "Make sure Claude is installed and in your PATH"
        exit 1
    fi
    
    log_message "claude CLI found - proceeding with issue monitoring"
    
    # Verify GitHub CLI is authenticated
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI is not authenticated. Run 'gh auth login'"
        exit 1
    fi
}

# Function to parse analysis file and automatically apply suggested GitHub labels
apply_suggested_labels() {
    local issue_number=$1
    local analysis_file=$2
    
    log_message "Parsing analysis to extract suggested labels for issue #${issue_number}..."
    
    # Extract lines that contain label suggestions from the analysis
    # Look for patterns like "- bug", "- enhancement", "- high", etc.
    local suggested_labels=""
    
    # Parse the analysis file to find suggested labels
    # This looks for common label patterns in the GitHub Labeling section
    while IFS= read -r line; do
        # Skip if we haven't reached the labeling section yet
        if [[ "$line" =~ "## STEP 2: GitHub Labeling" ]]; then
            # We're in the labeling section, start looking for labels
            continue
        fi
        
        # Look for label suggestions (lines that mention specific labels)
        if [[ "$line" =~ bug|enhancement|question|documentation|maintenance|high|medium|low|easy|moderate|complex|frontend|backend|database ]]; then
            # Extract potential labels from the line
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
    
    # Remove duplicates and apply labels
    suggested_labels=$(echo "$suggested_labels" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    
    if [[ -n "$suggested_labels" ]]; then
        log_message "Applying suggested labels: $suggested_labels"
        
        # Apply each label individually (GitHub CLI can be finicky with multiple labels)
        for label in $suggested_labels; do
            if gh issue edit "$issue_number" --repo "$REPO" --add-label "$label" 2>/dev/null; then
                log_success "Applied label: $label"
            else
                log_warning "Could not apply label: $label (may need to be created first)"
            fi
            sleep 1  # Brief pause between label applications
        done
    else
        log_warning "No clear labels found in analysis for issue #${issue_number}"
    fi
}

# Function to post the analysis as a comment on the GitHub issue
post_analysis_comment() {
    local issue_number=$1
    local analysis_file=$2
    
    log_message "Posting analysis as comment on issue #${issue_number}..."
    
    # Create a formatted comment with header and footer
    local temp_comment=$(mktemp)
    cat > "$temp_comment" << EOF
## 🤖 Automated Issue Analysis

Hi! I've automatically analyzed this issue using Claude Code. Here's my assessment:

---

$(cat "$analysis_file")

---

*This analysis was generated automatically by the PromptForge issue watcher. The suggestions above are AI-generated and should be reviewed by a human maintainer.*

*Issue analyzed at: $(date '+%Y-%m-%d %H:%M:%S UTC')*
EOF
    
    # Post the comment to the GitHub issue
    if gh issue comment "$issue_number" --repo "$REPO" --body-file "$temp_comment" 2>/dev/null; then
        log_success "Posted analysis comment on issue #${issue_number}"
        log_success "Comment visible at: https://github.com/${REPO}/issues/${issue_number}"
    else
        log_error "Failed to post comment on issue #${issue_number}"
        log_error "Check GitHub permissions for commenting on issues"
    fi
    
    # Clean up temporary comment file
    rm -f "$temp_comment"
}

# Function to process a single GitHub issue
# This handles the complete workflow for analyzing one issue
process_issue() {
    local issue_number=$1  # GitHub issue number (e.g., 42)
    local issue_title=$2   # The title of the issue
    
    log_message "Processing issue #${issue_number}: ${issue_title}"
    
    # Fetch the full issue content from GitHub
    local issue_body=$(gh issue view "$issue_number" --repo "$REPO" --json body --jq '.body')
    local issue_url="https://github.com/${REPO}/issues/${issue_number}"
    
    # Create a temporary file containing the complete issue analysis prompt
    # This file will be passed to clide (Claude Code) for processing
    local temp_file=$(mktemp)
    cat > "$temp_file" << EOF
# GitHub Issue Analysis Request

## Issue Details
- **Repository**: ${REPO}
- **Issue Number**: #${issue_number}
- **Title**: ${issue_title}
- **URL**: ${issue_url}

## Issue Description
${issue_body}

## Analysis Request
${CLAUDE_PROMPT}
EOF
    
    log_message "Running claude -p (headless mode) analysis for issue #${issue_number}..."
    
    # Create issues directory if it doesn't exist
    mkdir -p issues
    
    # Execute claude with -p flag (headless mode) and save output to markdown file in issues directory
    # The output file will be named: issues/issue_[number]_analysis.md
    if claude -p < "$temp_file" > "issues/issue_${issue_number}_analysis.md" 2>&1; then
        log_success "Analysis completed for issue #${issue_number}"
        log_success "Analysis saved to: issues/issue_${issue_number}_analysis.md"
        
        # Parse the analysis to extract suggested labels and apply them automatically
        apply_suggested_labels "$issue_number" "issues/issue_${issue_number}_analysis.md"
        
        # Post the analysis as a comment on the GitHub issue
        post_analysis_comment "$issue_number" "issues/issue_${issue_number}_analysis.md"
        
    else
        log_error "Failed to analyze issue #${issue_number}"
        log_error "Check that claude -p is working properly"
    fi
    
    # Clean up the temporary prompt file
    rm -f "$temp_file"
}

# Main function that continuously watches for new issues
# This is the heart of the script - it runs in an infinite loop
watch_issues() {
    log_message "Starting issue watcher for repository: ${REPO}"
    log_message "Checking for new issues every 60 seconds..."
    log_message "Press Ctrl+C to stop the watcher"
    
    # Infinite loop to continuously monitor for new issues
    while true; do
        log_message "Checking for new issues..."
        
        # Search for issues that don't have the "clide-analyzed" label
        # This prevents us from re-processing issues we've already handled
        local new_issues=$(gh issue list --repo "$REPO" --search "-label:clide-analyzed" --json number,title --limit 50)
        
        # Check if we found any new issues to process
        if [ "$new_issues" != "[]" ]; then
            # Process each new issue found
            echo "$new_issues" | jq -c '.[]' | while read -r issue; do
                # Extract issue number and title from JSON response
                local issue_number=$(echo "$issue" | jq -r '.number')
                local issue_title=$(echo "$issue" | jq -r '.title')
                
                log_success "Found new issue #${issue_number}: ${issue_title}"
                
                # Run the full analysis workflow for this issue
                process_issue "$issue_number" "$issue_title"
                
                # Mark the issue as processed by adding the "clide-analyzed" label
                # This prevents re-processing the same issue in future runs
                if gh issue edit "$issue_number" --repo "$REPO" --add-label "clide-analyzed" 2>/dev/null; then
                    log_success "Marked issue #${issue_number} as analyzed"
                else
                    log_warning "Could not add label to issue #${issue_number} (may need repo permissions)"
                fi
                
                # Brief pause between processing issues to avoid GitHub API rate limiting
                sleep 5
            done
        else
            log_message "No new issues found"
        fi
        
        # Wait 60 seconds before checking for new issues again
        log_message "Waiting 60 seconds before next check..."
        sleep 60
    done
}

# Function to handle graceful shutdown when user presses Ctrl+C
cleanup() {
    log_message "Shutting down issue watcher..."
    log_message "Thanks for using the GitHub issue watcher!"
    exit 0
}

# Set up signal handlers to catch Ctrl+C and other termination signals
trap cleanup SIGINT SIGTERM

# Main script execution function
main() {
    log_message "GitHub Issue Watcher for PromptForge"
    log_message "Repository: ${REPO}"
    
    # Verify all required tools are installed and configured
    check_dependencies
    
    # Setup required GitHub labels
    log_message "Checking and setting up required GitHub labels..."
    if [ -f "./setup_github_labels.sh" ]; then
        if ./setup_github_labels.sh "$REPO"; then
            log_success "GitHub labels are ready"
        else
            log_warning "Some labels could not be created, but continuing anyway"
        fi
    else
        log_warning "setup_github_labels.sh not found - skipping label setup"
        log_warning "Some operations may fail if required labels don't exist"
    fi
    
    # Start the continuous monitoring loop
    watch_issues
}

# Help documentation for users
show_help() {
    cat << EOF
GitHub Issue Watcher Script
===========================

This script monitors the protocolus/promptforge repository for new GitHub issues
and automatically runs Claude Code analysis on each new issue found.

Usage: $0 [options]

Options:
  -h, --help    Show this help message

Requirements:
  - GitHub CLI (gh) installed and authenticated with 'gh auth login'
  - jq installed for JSON processing
  - claude CLI installed with -p (headless) flag support

How it works:
1. Continuously checks for issues without the "clide-analyzed" label
2. For each new issue found:
   - Downloads the full issue content
   - Creates a detailed analysis prompt
   - Runs claude -p (Claude in headless mode) to analyze the issue
   - Saves analysis to issues/issue_[number]_analysis.md
   - Automatically applies suggested GitHub labels
   - Posts analysis as a comment on the GitHub issue
   - Marks issue with "clide-analyzed" label to prevent re-processing

Output files:
  - Analysis results saved in: issues/issue_[number]_analysis.md
  - Colored terminal output with timestamps
  - Automatic GitHub label application based on analysis
  - Analysis posted as comments on GitHub issues

To stop the watcher: Press Ctrl+C

Repository monitored: ${REPO}
EOF
}

# Command line argument handling
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        # Start the main program
        main "$@"
        ;;
esac