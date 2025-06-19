# Migration Guide: From Polling to Webhooks

This guide helps you transition from the polling-based `issue_watcher.sh` to the webhook-based approach for GitHub issue analysis.

## Migration Steps

### 1. Stop the Polling Script

First, stop any running instance of the polling script:

```bash
# Find the process
ps aux | grep issue_watcher

# Kill the process
kill [PID]

# Or use pkill
pkill -f issue_watcher.sh
```

### 2. Backup Current Configuration

```bash
# Backup the issues directory
cp -r /home/clide/promptforge/issues /home/clide/promptforge/issues.backup

# Note any custom modifications to issue_watcher.sh
cp issue_watcher.sh issue_watcher.sh.backup
```

### 3. Update Event Handler

Replace the standard webhook handler with the enhanced version:

```bash
cd /home/clide/promptforge/webhook-config

# Backup existing handler
cp handle-github-event.sh handle-github-event.sh.original

# Use the enhanced handler with issue processing
cp handle-github-event-with-issues.sh handle-github-event.sh

# Ensure it's executable
chmod +x handle-github-event.sh
```

### 4. Configure GitHub Webhook

Ensure your webhook is configured for issue events:

```bash
# List current webhooks
gh api repos/protocolus/promptforge/hooks

# Note the webhook ID, then update to include issues
gh api -X PATCH repos/protocolus/promptforge/hooks/[WEBHOOK_ID] \
  -f events[]="issues" \
  -f events[]="push" \
  -f events[]="pull_request" \
  -f events[]="release" \
  -f events[]="workflow_run"
```

### 5. Restart Webhook Service

```bash
# Find and stop current webhook service
ps aux | grep webhook
kill [PID]

# Start fresh with updated configuration
./start-webhook.sh

# Verify it's running
ps aux | grep webhook
tail -f logs/webhook-service.log
```

### 6. Test the Migration

Run the test script to verify everything works:

```bash
./test-issue-webhook.sh
```

### 7. Process Existing Unanalyzed Issues (Optional)

If you have existing issues that weren't analyzed by the polling script:

```bash
#!/bin/bash
# process-existing-issues.sh

REPO="protocolus/promptforge"

# Find issues without clide-analyzed label
echo "Finding unanalyzed issues..."
ISSUES=$(gh issue list --repo "$REPO" --search "-label:clide-analyzed" --json number --jq '.[].number')

for issue in $ISSUES; do
    echo "Triggering reanalysis for issue #$issue"
    
    # Remove and re-add a label to trigger webhook
    gh issue edit "$issue" --repo "$REPO" --add-label "needs-analysis"
    sleep 2
    gh issue edit "$issue" --repo "$REPO" --remove-label "needs-analysis"
    
    echo "Waiting for processing..."
    sleep 10
done

echo "All existing issues triggered for analysis"
```

## Comparison Checklist

Ensure your webhook setup matches the polling functionality:

| Feature | Polling | Webhook | Status |
|---------|---------|---------|---------|
| Detect new issues | ✓ Every 20s | ✓ Instant | ⬜ |
| Run Claude analysis | ✓ | ✓ | ⬜ |
| Apply suggested labels | ✓ | ✓ | ⬜ |
| Post analysis comment | ✓ | ✓ | ⬜ |
| Close non-viable issues | ✓ | ✓ | ⬜ |
| Add clide-analyzed label | ✓ | ✓ | ⬜ |
| Save analysis to file | ✓ | ✓ | ⬜ |
| Handle errors gracefully | ✓ | ✓ | ⬜ |

## Rollback Plan

If you need to revert to polling:

```bash
# Stop webhook processing of issues
cd /home/clide/promptforge/webhook-config
cp handle-github-event.sh.original handle-github-event.sh

# Restart webhook service
ps aux | grep webhook
kill [PID]
./start-webhook.sh

# Start polling script again
cd /home/clide/promptforge
./issue_watcher.sh &
```

## Monitoring After Migration

### Daily Checks

1. Check webhook is running:
   ```bash
   ps aux | grep webhook
   ```

2. Check recent issue processing:
   ```bash
   grep "issues" webhook-config/logs/github-events-$(date +%Y%m%d).log
   ```

3. Verify no issues are missed:
   ```bash
   gh issue list --repo protocolus/promptforge --search "-label:clide-analyzed"
   ```

### Setup Monitoring Script

```bash
#!/bin/bash
# monitor-webhook-health.sh

# Check webhook service
if ! pgrep -f webhook > /dev/null; then
    echo "ALERT: Webhook service not running!"
    # Optionally restart: ./start-webhook.sh
fi

# Check for recent issue events
RECENT=$(find logs -name "github-events-*.log" -mmin -120 -exec grep -l "issues" {} \; | wc -l)
if [ "$RECENT" -eq 0 ]; then
    echo "WARNING: No issue events in last 2 hours"
fi

# Check for unanalyzed issues
UNANALYZED=$(gh issue list --repo protocolus/promptforge --search "-label:clide-analyzed" --json number --jq '. | length')
if [ "$UNANALYZED" -gt 0 ]; then
    echo "WARNING: $UNANALYZED issues not analyzed"
fi
```

## Troubleshooting Migration Issues

### Issues Not Being Analyzed

1. Verify webhook receives issue events:
   ```bash
   tail -f logs/github-events-*.log
   # Create a test issue and watch for logs
   ```

2. Check Claude CLI works:
   ```bash
   echo "test" | claude -p
   ```

3. Verify GitHub CLI authentication:
   ```bash
   gh auth status
   ```

### Different Behavior Than Polling

The webhook approach should behave identically to polling, but:

1. **Timing**: Webhooks process immediately vs 20-second intervals
2. **Reliability**: Webhooks won't miss issues during downtime
3. **Duplicate Processing**: Webhooks check for existing labels to prevent reprocessing

### Performance Issues

If webhook processing is slow:

1. Check system resources:
   ```bash
   top
   df -h
   ```

2. Review Claude API limits
3. Consider processing issues asynchronously

## Benefits After Migration

1. **Instant Response**: Issues analyzed within seconds of creation
2. **Resource Efficiency**: No constant polling consuming CPU/API quota  
3. **Reliability**: GitHub retries failed webhook deliveries
4. **Scalability**: Handles high issue volumes without delays
5. **Monitoring**: Better visibility into processing via webhook logs

## Next Steps

After successful migration:

1. Remove the polling script from any startup scripts
2. Update documentation to reflect webhook approach
3. Set up log rotation for webhook logs
4. Consider adding more GitHub event types to webhook
5. Monitor for a week to ensure stability

The webhook approach is the recommended production solution for GitHub issue analysis.