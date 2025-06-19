#!/bin/bash

# Script to set up GitHub webhook using GitHub CLI
# Repository: protocolus/promptforge

set -e

REPO="protocolus/promptforge"
WEBHOOK_URL="https://clidecoder.com/hooks/github-webhook"
CONFIG_FILE="/home/clide/promptforge/webhook-config/hooks.json"

echo "GitHub Webhook Setup for $REPO"
echo "================================"
echo ""

# Check if gh is authenticated
if ! gh auth status &>/dev/null; then
    echo "GitHub CLI is not authenticated. Please run:"
    echo "gh auth login"
    echo ""
    echo "Then run this script again."
    exit 1
fi

# Generate secret if not already in config
CURRENT_SECRET=$(grep -oP '"secret":\s*"\K[^"]+' "$CONFIG_FILE" 2>/dev/null || echo "")

if [ "$CURRENT_SECRET" = "your-secret-here" ] || [ -z "$CURRENT_SECRET" ]; then
    echo "Generating new webhook secret..."
    NEW_SECRET=$(openssl rand -hex 32)
    
    # Update hooks.json with the new secret
    sed -i "s/\"secret\": \"your-secret-here\"/\"secret\": \"$NEW_SECRET\"/" "$CONFIG_FILE"
    
    echo "✓ Secret generated and saved to hooks.json"
    WEBHOOK_SECRET="$NEW_SECRET"
else
    echo "Using existing secret from hooks.json"
    WEBHOOK_SECRET="$CURRENT_SECRET"
fi

# Check if webhook already exists
echo ""
echo "Checking for existing webhooks..."
EXISTING_WEBHOOK=$(gh api repos/$REPO/hooks --jq '.[] | select(.config.url == "'$WEBHOOK_URL'") | .id' 2>/dev/null || echo "")

if [ -n "$EXISTING_WEBHOOK" ]; then
    echo "Found existing webhook with ID: $EXISTING_WEBHOOK"
    echo -n "Do you want to update it? (y/n): "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Updating webhook..."
        gh api -X PATCH repos/$REPO/hooks/$EXISTING_WEBHOOK \
            --field config[url]="$WEBHOOK_URL" \
            --field config[content_type]="json" \
            --field config[secret]="$WEBHOOK_SECRET" \
            --field config[insecure_ssl]="0" \
            --field events[]="*" \
            --field active=true
        echo "✓ Webhook updated successfully!"
    else
        echo "Skipping update."
        exit 0
    fi
else
    echo "Creating new webhook..."
    gh api repos/$REPO/hooks \
        --method POST \
        --field name="web" \
        --field active=true \
        --field events[]="*" \
        --field config[url]="$WEBHOOK_URL" \
        --field config[content_type]="json" \
        --field config[secret]="$WEBHOOK_SECRET" \
        --field config[insecure_ssl]="0"
    
    echo "✓ Webhook created successfully!"
fi

echo ""
echo "Webhook Configuration:"
echo "====================="
echo "URL: $WEBHOOK_URL"
echo "Events: All events"
echo "Secret: Stored in hooks.json"
echo ""
echo "Testing webhook with a ping..."
WEBHOOK_ID=$(gh api repos/$REPO/hooks --jq '.[] | select(.config.url == "'$WEBHOOK_URL'") | .id')
gh api -X POST repos/$REPO/hooks/$WEBHOOK_ID/pings

echo ""
echo "✓ Ping sent! Check your webhook logs at:"
echo "  webhook-config/logs/github-events-*.log"
echo ""
echo "Make sure your webhook service is running:"
echo "  cd webhook-config && ./start-webhook.sh"