#!/bin/bash

# Script to clean up the test repository

set -e

# Load repository info
if [ ! -f "/home/clide/promptforge/webhook-config/test-repo-info.json" ]; then
    echo "No test repository found to clean up."
    exit 0
fi

REPO_INFO=$(cat /home/clide/promptforge/webhook-config/test-repo-info.json)
REPO_FULL_NAME=$(echo "$REPO_INFO" | jq -r .repo_full_name)
LOCAL_PATH=$(echo "$REPO_INFO" | jq -r .local_path)

echo "Test Repository Cleanup"
echo "======================="
echo ""
echo "This will delete:"
echo "- Repository: $REPO_FULL_NAME"
echo "- Local clone: $LOCAL_PATH"
echo ""
echo -n "Are you sure you want to delete the test repository? (y/n): "
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Delete the repository
echo ""
echo "Deleting repository on GitHub..."
gh repo delete "$REPO_FULL_NAME" --yes

# Remove local clone
echo "Removing local clone..."
rm -rf "$LOCAL_PATH"

# Remove repo info file
rm -f /home/clide/promptforge/webhook-config/test-repo-info.json

echo ""
echo "✓ Test repository cleaned up successfully!"