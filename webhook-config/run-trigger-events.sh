#!/bin/bash

# Wrapper script to trigger events from the correct directory

REPO_INFO=$(cat /home/clide/promptforge/webhook-config/test-repo-info.json)
LOCAL_PATH=$(echo "$REPO_INFO" | jq -r .local_path)

# Configure git and run trigger script
bash -c "cd '$LOCAL_PATH' && git config user.email 'webhook-test@clidecoder.com' && git config user.name 'Webhook Test' && /home/clide/promptforge/webhook-config/trigger-test-events.sh"