#!/bin/bash

echo "Testing GitHub Issue Webhook Integration"
echo "======================================="

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

# Check if webhook service is running
if pgrep -f webhook > /dev/null; then
    echo -e "${GREEN}✓${NC} Webhook service is running"
else
    echo -e "${RED}✗${NC} Webhook service is not running"
    echo "  Start it with: ./start-webhook.sh"
    exit 1
fi

# Check GitHub CLI
if command -v gh &> /dev/null; then
    echo -e "${GREEN}✓${NC} GitHub CLI is installed"
else
    echo -e "${RED}✗${NC} GitHub CLI is not installed"
    exit 1
fi

# Check Claude CLI
if command -v claude &> /dev/null; then
    echo -e "${GREEN}✓${NC} Claude CLI is installed"
else
    echo -e "${RED}✗${NC} Claude CLI is not installed"
    exit 1
fi

# Repository to test
REPO="${1:-protocolus/promptforge}"
echo -e "\n${YELLOW}Testing repository:${NC} $REPO"

# Create test issue
echo -e "\n${YELLOW}Creating test issue...${NC}"
TIMESTAMP=$(date +%s)
ISSUE_OUTPUT=$(gh issue create --repo "$REPO" \
  --title "Webhook Test: $TIMESTAMP" \
  --body "This is an automated test issue for webhook verification.

## Test Details
- Created at: $(date)
- Purpose: Verify webhook processing
- Expected outcome: Claude Code analysis should be triggered

This issue should be automatically analyzed and labeled." \
  --label "test" 2>&1)

if [ $? -eq 0 ]; then
    ISSUE_NUMBER=$(echo "$ISSUE_OUTPUT" | grep -o '[0-9]*$')
    ISSUE_URL=$(echo "$ISSUE_OUTPUT" | grep -o 'https://[^ ]*')
    echo -e "${GREEN}✓${NC} Created test issue #$ISSUE_NUMBER"
    echo "  URL: $ISSUE_URL"
else
    echo -e "${RED}✗${NC} Failed to create test issue"
    echo "$ISSUE_OUTPUT"
    exit 1
fi

# Monitor webhook processing
echo -e "\n${YELLOW}Monitoring webhook processing...${NC}"
echo "Waiting for webhook to process the issue (up to 60 seconds)..."

# Function to check if issue has been analyzed
check_analyzed() {
    gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json labels | grep -q "clide-analyzed"
}

# Wait for analysis with timeout
SECONDS=0
TIMEOUT=60
while [ $SECONDS -lt $TIMEOUT ]; do
    if check_analyzed; then
        echo -e "\n${GREEN}✓${NC} Issue was analyzed successfully!"
        break
    fi
    echo -n "."
    sleep 5
done

if [ $SECONDS -ge $TIMEOUT ]; then
    echo -e "\n${RED}✗${NC} Timeout: Issue was not analyzed within $TIMEOUT seconds"
fi

# Check results
echo -e "\n${YELLOW}Checking results...${NC}"

# Check for clide-analyzed label
if check_analyzed; then
    echo -e "${GREEN}✓${NC} 'clide-analyzed' label was applied"
else
    echo -e "${RED}✗${NC} 'clide-analyzed' label was not applied"
fi

# Check for analysis comment
COMMENT_COUNT=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json comments --jq '.comments | length')
if [ "$COMMENT_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Analysis comment was posted ($COMMENT_COUNT comments)"
    
    # Show first few lines of the comment
    echo -e "\n${YELLOW}Analysis preview:${NC}"
    gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json comments --jq '.comments[0].body' | head -20
    echo "..."
else
    echo -e "${RED}✗${NC} No analysis comment found"
fi

# Check for other labels
LABELS=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json labels --jq '.labels[].name' | tr '\n' ', ' | sed 's/,$//')
if [ -n "$LABELS" ]; then
    echo -e "\n${YELLOW}Applied labels:${NC} $LABELS"
fi

# Check if analysis file was created
ANALYSIS_FILE="/home/clide/promptforge/issues/issue_${ISSUE_NUMBER}_analysis.md"
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
    grep "Issue #$ISSUE_NUMBER" "$LOG_FILE" | tail -5
else
    echo "Log file not found: $LOG_FILE"
fi

# Cleanup option
echo -e "\n${YELLOW}Cleanup:${NC}"
read -p "Delete test issue #$ISSUE_NUMBER? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if gh issue close "$ISSUE_NUMBER" --repo "$REPO" --comment "Test completed - closing test issue" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Test issue closed"
    else
        echo -e "${RED}✗${NC} Failed to close test issue"
    fi
fi

echo -e "\n${YELLOW}Test complete!${NC}"