#!/bin/bash

# Start webhook service
# Default port: 9000 (can be changed with PORT environment variable)

PORT=${PORT:-9000}
HOOKS_PATH="/home/clide/promptforge/webhook-config/hooks.json"
LOG_FILE="/home/clide/promptforge/webhook-config/logs/webhook-service.log"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

echo "Starting webhook service on port $PORT..."
echo "Hooks configuration: $HOOKS_PATH"
echo "Logs will be written to: $LOG_FILE"
echo ""
echo "GitHub webhook URL will be: http://your-server:$PORT/hooks/github-webhook"
echo ""
echo "Press Ctrl+C to stop the service"
echo "----------------------------------------"

# Start webhook with verbose output
webhook -hooks "$HOOKS_PATH" -port "$PORT" -verbose 2>&1 | tee -a "$LOG_FILE"