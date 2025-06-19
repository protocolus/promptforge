#!/bin/bash

# Script to manage GitHub webhooks (list, test, delete)
# Repository: protocolus/promptforge

set -e

REPO="protocolus/promptforge"
WEBHOOK_URL="https://clidecoder.com/hooks/github-webhook"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if gh is authenticated
if ! gh auth status &>/dev/null; then
    echo -e "${RED}GitHub CLI is not authenticated. Please run:${NC}"
    echo "gh auth login"
    exit 1
fi

show_menu() {
    echo ""
    echo "GitHub Webhook Management for $REPO"
    echo "===================================="
    echo "1. List all webhooks"
    echo "2. Test webhook (send ping)"
    echo "3. View webhook details"
    echo "4. View recent deliveries"
    echo "5. Delete webhook"
    echo "6. Exit"
    echo ""
}

list_webhooks() {
    echo -e "${YELLOW}Fetching webhooks...${NC}"
    gh api repos/$REPO/hooks --jq '.[] | "ID: \(.id) | URL: \(.config.url) | Active: \(.active) | Events: \(.events | join(", "))"' || echo "No webhooks found"
}

test_webhook() {
    WEBHOOK_ID=$(gh api repos/$REPO/hooks --jq '.[] | select(.config.url == "'$WEBHOOK_URL'") | .id' 2>/dev/null || echo "")
    
    if [ -z "$WEBHOOK_ID" ]; then
        echo -e "${RED}Webhook not found for URL: $WEBHOOK_URL${NC}"
        return
    fi
    
    echo -e "${YELLOW}Sending ping to webhook ID: $WEBHOOK_ID...${NC}"
    gh api -X POST repos/$REPO/hooks/$WEBHOOK_ID/pings
    echo -e "${GREEN}✓ Ping sent successfully!${NC}"
    echo "Check your logs at: webhook-config/logs/github-events-*.log"
}

view_webhook_details() {
    WEBHOOK_ID=$(gh api repos/$REPO/hooks --jq '.[] | select(.config.url == "'$WEBHOOK_URL'") | .id' 2>/dev/null || echo "")
    
    if [ -z "$WEBHOOK_ID" ]; then
        echo -e "${RED}Webhook not found for URL: $WEBHOOK_URL${NC}"
        return
    fi
    
    echo -e "${YELLOW}Webhook Details:${NC}"
    gh api repos/$REPO/hooks/$WEBHOOK_ID --jq '. | {
        id: .id,
        url: .config.url,
        content_type: .config.content_type,
        insecure_ssl: .config.insecure_ssl,
        active: .active,
        events: .events,
        created_at: .created_at,
        updated_at: .updated_at,
        last_response: .last_response
    }'
}

view_recent_deliveries() {
    WEBHOOK_ID=$(gh api repos/$REPO/hooks --jq '.[] | select(.config.url == "'$WEBHOOK_URL'") | .id' 2>/dev/null || echo "")
    
    if [ -z "$WEBHOOK_ID" ]; then
        echo -e "${RED}Webhook not found for URL: $WEBHOOK_URL${NC}"
        return
    fi
    
    echo -e "${YELLOW}Recent webhook deliveries:${NC}"
    gh api repos/$REPO/hooks/$WEBHOOK_ID/deliveries --jq '.[] | 
        "ID: \(.id) | Event: \(.event) | Action: \(.action // "N/A") | Status: \(.status_code) | Delivered: \(.delivered_at)"' | head -10
    
    echo ""
    echo -n "View details of a specific delivery? Enter delivery ID (or press Enter to skip): "
    read -r delivery_id
    
    if [ -n "$delivery_id" ]; then
        echo -e "${YELLOW}Delivery details:${NC}"
        gh api repos/$REPO/hooks/$WEBHOOK_ID/deliveries/$delivery_id --jq '{
            status_code: .status_code,
            event: .event,
            action: .action,
            delivered_at: .delivered_at,
            duration: .duration,
            request_headers: .request.headers,
            response_headers: .response.headers,
            response_body: .response.payload
        }'
    fi
}

delete_webhook() {
    WEBHOOK_ID=$(gh api repos/$REPO/hooks --jq '.[] | select(.config.url == "'$WEBHOOK_URL'") | .id' 2>/dev/null || echo "")
    
    if [ -z "$WEBHOOK_ID" ]; then
        echo -e "${RED}Webhook not found for URL: $WEBHOOK_URL${NC}"
        return
    fi
    
    echo -e "${RED}WARNING: This will delete the webhook for $WEBHOOK_URL${NC}"
    echo -n "Are you sure? (y/n): "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        gh api -X DELETE repos/$REPO/hooks/$WEBHOOK_ID
        echo -e "${GREEN}✓ Webhook deleted successfully!${NC}"
    else
        echo "Deletion cancelled."
    fi
}

# Main loop
while true; do
    show_menu
    echo -n "Select an option: "
    read -r choice
    
    case $choice in
        1) list_webhooks ;;
        2) test_webhook ;;
        3) view_webhook_details ;;
        4) view_recent_deliveries ;;
        5) delete_webhook ;;
        6) echo "Exiting..."; exit 0 ;;
        *) echo -e "${RED}Invalid option. Please try again.${NC}" ;;
    esac
    
    echo ""
    echo -n "Press Enter to continue..."
    read -r
done