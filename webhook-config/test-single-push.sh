#!/bin/bash

# Quick test to create a push event

REPO_INFO=$(cat /home/clide/promptforge/webhook-config/test-repo-info.json)
LOCAL_PATH=$(echo "$REPO_INFO" | jq -r .local_path)

echo "Creating a test push event..."
bash -c "cd '$LOCAL_PATH' && echo '## Test push at $(date)' >> README.md && git add README.md && git commit -m 'Test webhook push event' && git push"

echo ""
echo "✓ Push event triggered!"
echo ""
echo "Check the webhook logs:"
echo "tail -f /home/clide/promptforge/webhook-config/logs/github-events-*.log"