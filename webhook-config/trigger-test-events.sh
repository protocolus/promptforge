#!/bin/bash

# Script to trigger various GitHub events on the test repository

set -e

# Load repository info
if [ ! -f "/home/clide/promptforge/webhook-config/test-repo-info.json" ]; then
    echo "No test repository found. Please run ./create-test-repo.sh first"
    exit 1
fi

REPO_INFO=$(cat /home/clide/promptforge/webhook-config/test-repo-info.json)
REPO_FULL_NAME=$(echo "$REPO_INFO" | jq -r .repo_full_name)
LOCAL_PATH=$(echo "$REPO_INFO" | jq -r .local_path)

echo "Triggering GitHub Events on $REPO_FULL_NAME"
echo "==========================================="
echo ""

cd "$LOCAL_PATH"

# Configure git if not already configured
if ! git config user.email > /dev/null 2>&1; then
    git config user.email "webhook-test@clidecoder.com"
    git config user.name "Webhook Test"
fi

# 1. Push event - Create and push a commit
echo "1. Creating a push event..."
echo "## Test File $(date)" > test-file-$(date +%s).md
git add .
git commit -m "Test commit: $(date)"
git push origin main
echo "✓ Push event triggered"
sleep 2

# 2. Create an issue
echo ""
echo "2. Creating an issue..."
ISSUE_RESPONSE=$(gh issue create \
    --title "Test Issue: Webhook Integration $(date +%H:%M:%S)" \
    --body "This is a test issue to verify webhook integration is working correctly.")
ISSUE_NUMBER=$(echo "$ISSUE_RESPONSE" | grep -oP '#\K\d+')
echo "✓ Issue #$ISSUE_NUMBER created"
sleep 2

# 3. Comment on the issue
echo ""
echo "3. Adding a comment to the issue..."
gh issue comment "$ISSUE_NUMBER" --body "This is a test comment on the issue."
echo "✓ Comment added"
sleep 2

# 4. Close the issue
echo ""
echo "4. Closing the issue..."
gh issue close "$ISSUE_NUMBER"
echo "✓ Issue closed"
sleep 2

# 5. Create a pull request
echo ""
echo "5. Creating a pull request..."
git checkout -b test-pr-branch-$(date +%s)
echo "## PR Test File" > pr-test-file.md
git add pr-test-file.md
git commit -m "Add PR test file"
git push -u origin HEAD

PR_RESPONSE=$(gh pr create \
    --title "Test PR: Webhook Integration $(date +%H:%M:%S)" \
    --body "This is a test pull request to verify webhook integration.")
PR_NUMBER=$(echo "$PR_RESPONSE" | grep -oP 'pull/\K\d+')
echo "✓ Pull request #$PR_NUMBER created"
sleep 2

# 6. Add a label to the PR
echo ""
echo "6. Adding a label to the PR..."
gh pr edit "$PR_NUMBER" --add-label "enhancement" 2>/dev/null || echo "Note: Label 'enhancement' might not exist"
echo "✓ Label operation completed"
sleep 2

# 7. Create a release
echo ""
echo "7. Creating a release..."
TAG_NAME="v0.0.$(date +%s)"
gh release create "$TAG_NAME" \
    --title "Test Release $(date +%H:%M:%S)" \
    --notes "This is a test release to verify webhook integration" \
    --generate-notes
echo "✓ Release $TAG_NAME created"

# Return to main branch
git checkout main

echo ""
echo "==============================================="
echo "✓ All test events have been triggered!"
echo ""
echo "Check the webhook logs at:"
echo "  /home/clide/promptforge/webhook-config/logs/github-events-*.log"
echo ""
echo "View events on GitHub:"
echo "  https://github.com/$REPO_FULL_NAME"