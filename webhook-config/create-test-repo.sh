#!/bin/bash

# Script to create a test repository and configure webhook

set -e

# Configuration
REPO_NAME="webhook-test-$(date +%Y%m%d-%H%M%S)"
WEBHOOK_URL="https://clidecoder.com/hooks/github-webhook"
CONFIG_FILE="/home/clide/promptforge/webhook-config/hooks.json"

echo "GitHub Test Repository Setup"
echo "============================"
echo ""

# Check authentication
if ! gh auth status &>/dev/null; then
    echo "GitHub CLI is not authenticated. Please run:"
    echo "gh auth login"
    exit 1
fi

# Get current user
GITHUB_USER=$(gh api user --jq .login)
echo "Creating repository for user: $GITHUB_USER"

# Create the repository
echo "Creating test repository: $REPO_NAME..."
gh repo create "$REPO_NAME" \
    --public \
    --description "Test repository for webhook integration" \
    --clone=false \
    --add-readme

REPO_FULL_NAME="$GITHUB_USER/$REPO_NAME"
echo "✓ Repository created: $REPO_FULL_NAME"

# Get the webhook secret
WEBHOOK_SECRET=$(grep -oP '"secret":\s*"\K[^"]+' "$CONFIG_FILE")

# Create webhook
echo ""
echo "Setting up webhook..."
WEBHOOK_RESPONSE=$(gh api repos/$REPO_FULL_NAME/hooks \
    --method POST \
    --field name="web" \
    --field active=true \
    --field events[]="*" \
    --field config[url]="$WEBHOOK_URL" \
    --field config[content_type]="json" \
    --field config[secret]="$WEBHOOK_SECRET" \
    --field config[insecure_ssl]="0")

WEBHOOK_ID=$(echo "$WEBHOOK_RESPONSE" | jq -r .id)
echo "✓ Webhook created with ID: $WEBHOOK_ID"

# Clone the repository locally
TEMP_DIR="/tmp/$REPO_NAME"
echo ""
echo "Cloning repository to: $TEMP_DIR"
gh repo clone "$REPO_FULL_NAME" "$TEMP_DIR"

# Save repository info
cat > /home/clide/promptforge/webhook-config/test-repo-info.json << EOF
{
  "repo_name": "$REPO_NAME",
  "repo_full_name": "$REPO_FULL_NAME",
  "webhook_id": "$WEBHOOK_ID",
  "webhook_url": "$WEBHOOK_URL",
  "local_path": "$TEMP_DIR",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

echo ""
echo "Repository Information:"
echo "======================="
echo "Name: $REPO_FULL_NAME"
echo "URL: https://github.com/$REPO_FULL_NAME"
echo "Local path: $TEMP_DIR"
echo "Webhook ID: $WEBHOOK_ID"
echo ""
echo "✓ Test repository is ready!"
echo ""
echo "To trigger events, run:"
echo "  ./trigger-test-events.sh"
echo ""
echo "To clean up when done, run:"
echo "  ./cleanup-test-repo.sh"