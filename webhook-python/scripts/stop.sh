#!/bin/bash

# Stop script for GitHub Webhook Handler

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Stopping GitHub Webhook Handler${NC}"

# Try Docker Compose first
if command -v docker-compose &> /dev/null && [ -f docker-compose.yml ]; then
    if docker-compose ps | grep -q webhook-handler; then
        echo "Stopping Docker Compose services..."
        docker-compose down
        echo -e "${GREEN}✓${NC} Docker Compose services stopped"
        exit 0
    fi
fi

# Try standalone Docker container
if command -v docker &> /dev/null; then
    if docker ps | grep -q github-webhook-handler; then
        echo "Stopping Docker container..."
        docker stop github-webhook-handler
        docker rm github-webhook-handler
        echo -e "${GREEN}✓${NC} Docker container stopped"
        exit 0
    fi
fi

# Try PID file
if [ -f webhook_handler.pid ]; then
    PID=$(cat webhook_handler.pid)
    if kill -0 $PID 2>/dev/null; then
        echo "Stopping webhook handler (PID: $PID)..."
        kill $PID
        rm webhook_handler.pid
        echo -e "${GREEN}✓${NC} Webhook handler stopped"
    else
        echo -e "${YELLOW}PID file exists but process not running${NC}"
        rm webhook_handler.pid
    fi
    exit 0
fi

# Try to find and kill the process
PIDS=$(pgrep -f "webhook_handler.main:app" || true)
if [ -n "$PIDS" ]; then
    echo "Found webhook handler processes: $PIDS"
    kill $PIDS
    echo -e "${GREEN}✓${NC} Webhook handler processes stopped"
else
    echo -e "${YELLOW}No webhook handler processes found${NC}"
fi

echo -e "${GREEN}Cleanup complete${NC}"