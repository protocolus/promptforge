#!/bin/bash

echo "Testing GitHub PR Webhook Integration"
echo "====================================="

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Repository to test
REPO="${1:-protocolus/promptforge}"
echo -e "\n${YELLOW}Testing repository:${NC} $REPO"

# Create a test branch and PR
echo -e "\n${YELLOW}Creating test branch and PR...${NC}"
TIMESTAMP=$(date +%s)
BRANCH_NAME="test-webhook-pr-$TIMESTAMP"

# Create test branch
git checkout -b "$BRANCH_NAME" 2>/dev/null || {
    echo -e "${RED}✗${NC} Failed to create test branch"
    exit 1
}

# Make a small change
echo "# Test PR for Webhook Integration" > test-pr-$TIMESTAMP.md
echo "" >> test-pr-$TIMESTAMP.md
echo "This is a test file created to verify PR webhook functionality." >> test-pr-$TIMESTAMP.md
echo "" >> test-pr-$TIMESTAMP.md
echo "Created at: $(date)" >> test-pr-$TIMESTAMP.md

git add test-pr-$TIMESTAMP.md
git commit -m "Add test file for PR webhook testing

This commit creates a test file to verify that the PR webhook
system correctly processes new pull requests with Claude Code
analysis.

- Added test markdown file
- Includes timestamp for uniqueness
- Tests basic PR creation workflow"

# Push branch
git push -u origin "$BRANCH_NAME" || {
    echo -e "${RED}✗${NC} Failed to push test branch"
    exit 1
}

# Create PR
echo -e "\n${YELLOW}Creating pull request...${NC}"
PR_OUTPUT=$(gh pr create --repo "$REPO" \
  --title "Test PR: Webhook Integration $TIMESTAMP" \
  --body "## Purpose
This is an automated test PR to verify webhook processing of pull requests.

## Changes
- Added a test markdown file with timestamp
- Simple change to test PR analysis workflow

## Expected Behavior
The webhook should:
1. Detect this new PR
2. Run Claude Code analysis
3. Post analysis as a comment
4. Apply appropriate labels

## Test Details
- Created: $(date)
- Branch: $BRANCH_NAME
- Automated: Yes" \
  --head "$BRANCH_NAME" \
  --draft 2>&1)

if [ $? -eq 0 ]; then
    PR_NUMBER=$(echo "$PR_OUTPUT" | grep -o '#[0-9]*' | tr -d '#')
    PR_URL=$(echo "$PR_OUTPUT" | grep -o 'https://[^ ]*')
    echo -e "${GREEN}✓${NC} Created test PR #$PR_NUMBER"
    echo "  URL: $PR_URL"
else
    echo -e "${RED}✗${NC} Failed to create test PR"
    echo "$PR_OUTPUT"
    exit 1
fi

# Monitor webhook processing
echo -e "\n${YELLOW}Monitoring webhook processing...${NC}"
echo "Waiting for webhook to process the PR (up to 60 seconds)..."

# Wait for analysis with timeout
SECONDS=0
TIMEOUT=60
while [ $SECONDS -lt $TIMEOUT ]; do
    COMMENT_COUNT=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json comments --jq '.comments | length')
    if [ "$COMMENT_COUNT" -gt 0 ]; then
        # Check if it's our analysis comment
        if gh pr view "$PR_NUMBER" --repo "$REPO" --json comments --jq '.comments[].body' | grep -q "Automated PR Review"; then
            echo -e "\n${GREEN}✓${NC} PR analysis completed!"
            break
        fi
    fi
    echo -n "."
    sleep 5
done

if [ $SECONDS -ge $TIMEOUT ]; then
    echo -e "\n${RED}✗${NC} Timeout: PR was not analyzed within $TIMEOUT seconds"
fi

# Check results
echo -e "\n${YELLOW}Checking results...${NC}"

# Check for analysis comment
COMMENT_COUNT=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json comments --jq '.comments | length')
if [ "$COMMENT_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Analysis comment was posted ($COMMENT_COUNT comments)"
    
    # Show preview of analysis
    echo -e "\n${YELLOW}Analysis preview:${NC}"
    gh pr view "$PR_NUMBER" --repo "$REPO" --json comments --jq '.comments[0].body' | head -15
    echo "..."
else
    echo -e "${RED}✗${NC} No analysis comment found"
fi

# Check for labels
LABELS=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json labels --jq '.labels[].name' | tr '\n' ', ' | sed 's/,$//')
if [ -n "$LABELS" ]; then
    echo -e "\n${YELLOW}Applied labels:${NC} $LABELS"
fi

# Check if analysis file was created
ANALYSIS_FILE="/home/clide/promptforge/pull_requests/pr_${PR_NUMBER}_analysis.md"
if [ -f "$ANALYSIS_FILE" ]; then
    echo -e "${GREEN}✓${NC} Analysis file created: $ANALYSIS_FILE"
    echo -e "\n${YELLOW}Analysis file size:${NC} $(wc -c < "$ANALYSIS_FILE") bytes"
else
    echo -e "${RED}✗${NC} Analysis file not found: $ANALYSIS_FILE"
fi

# Check webhook logs
echo -e "\n${YELLOW}Recent webhook logs:${NC}"
LOG_FILE="/home/clide/promptforge/webhook-config/logs/github-events-$(date +%Y%m%d).log"
if [ -f "$LOG_FILE" ]; then
    grep "PR #$PR_NUMBER" "$LOG_FILE" | tail -5
else
    echo "Log file not found: $LOG_FILE"
fi

# Test review request (optional)
echo -e "\n${YELLOW}Testing review request...${NC}"
read -p "Request a review from someone? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter GitHub username to request review from: " reviewer
    if [ -n "$reviewer" ]; then
        if gh pr edit "$PR_NUMBER" --repo "$REPO" --add-reviewer "$reviewer" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Review requested from $reviewer"
            echo "This should trigger a review analysis webhook..."
        else
            echo -e "${RED}✗${NC} Failed to request review from $reviewer"
        fi
    fi
fi

# Cleanup option
echo -e "\n${YELLOW}Cleanup:${NC}"
read -p "Close and delete test PR #$PR_NUMBER? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Close PR
    if gh pr close "$PR_NUMBER" --repo "$REPO" --comment "Test completed - closing test PR" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Test PR closed"
    else
        echo -e "${RED}✗${NC} Failed to close test PR"
    fi
    
    # Switch back to main and delete branch
    git checkout main 2>/dev/null
    git branch -D "$BRANCH_NAME" 2>/dev/null
    git push origin --delete "$BRANCH_NAME" 2>/dev/null
    
    # Remove test file
    rm -f "test-pr-$TIMESTAMP.md"
    
    echo -e "${GREEN}✓${NC} Cleanup completed"
fi

echo -e "\n${YELLOW}Test complete!${NC}"