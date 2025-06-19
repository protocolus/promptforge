# GitHub Webhook Setup Guide

This guide documents the complete GitHub webhook setup for receiving all GitHub events at `https://clidecoder.com/hooks/github-webhook`.

## Overview

The webhook system consists of:
- **Webhook Service**: Running on port 9000 using the `webhook` tool
- **Nginx Proxy**: Routes HTTPS traffic from `clidecoder.com/hooks` to the webhook service
- **Event Handler**: Bash script that processes and logs all GitHub events
- **Security**: HMAC-SHA256 signature validation for all incoming webhooks

## Architecture

```
GitHub → HTTPS → Nginx (clidecoder.com/hooks) → Webhook Service (port 9000) → Event Handler Script → Logs
```

## Quick Start

### 1. Start the Webhook Service

```bash
cd /home/clide/promptforge/webhook-config
./start-webhook.sh
```

The service will run on port 9000 and log to `logs/webhook-service.log`.

### 2. Configure a GitHub Repository

#### Option A: Using GitHub CLI (Recommended)
```bash
# Authenticate with GitHub
gh auth login

# Run the setup script
./setup-github-webhook.sh
```

#### Option B: Manual Setup
1. Go to your repository settings → Webhooks → Add webhook
2. Configure:
   - **Payload URL**: `https://clidecoder.com/hooks/github-webhook`
   - **Content type**: `application/json`
   - **Secret**: Copy from `hooks.json`
   - **Events**: Select "Send me everything"

### 3. Monitor Events

```bash
# Watch events in real-time
tail -f logs/github-events-*.log

# View webhook service logs
tail -f logs/webhook-service.log
```

## Configuration Files

### hooks.json
Main webhook configuration file that defines:
- Webhook ID and URL path
- Script to execute for events
- HMAC secret for validation
- Arguments and environment variables passed to the handler

### handle-github-event.sh
Event processing script that:
- Logs all incoming events with timestamps
- Parses specific event types (push, pull_request, issues, etc.)
- Can be extended with custom logic for each event type

## Directory Structure

```
webhook-config/
├── hooks.json                    # Webhook configuration
├── handle-github-event.sh        # Event handler script
├── start-webhook.sh             # Service startup script
├── update-nginx.sh              # Nginx configuration updater
├── setup-github-webhook.sh      # GitHub webhook setup via API
├── manage-webhook.sh            # Webhook management tool
├── create-test-repo.sh          # Test repository creator
├── trigger-test-events.sh       # Test event generator
├── cleanup-test-repo.sh         # Test cleanup script
├── logs/                        # Log directory
│   ├── github-events-*.log      # Event logs by date
│   └── webhook-service.log      # Service logs
└── README.md                    # Setup instructions
```

## Security

### Webhook Secret
- Stored in `hooks.json`
- Used for HMAC-SHA256 signature validation
- GitHub signs each payload with this secret
- Webhook service validates signature before processing

### Generate a New Secret
```bash
openssl rand -hex 32
```

Update the secret in `hooks.json` and your GitHub webhook settings.

## Event Types

The webhook receives all GitHub events including:

- **Repository Events**: push, create, delete, fork, etc.
- **Pull Request Events**: opened, closed, merged, review, etc.
- **Issue Events**: opened, closed, commented, labeled, etc.
- **Release Events**: published, created, deleted, etc.
- **Workflow Events**: workflow_run, workflow_job, etc.
- **Organization Events**: member added/removed, team changes, etc.
- **Security Events**: security advisory, vulnerability alerts, etc.

## Customizing Event Handling

Edit `handle-github-event.sh` to add custom logic:

```bash
case "$EVENT_TYPE" in
    "push")
        if [ "$BRANCH" = "main" ]; then
            # Trigger CI/CD pipeline
            ./deploy.sh
        fi
        ;;
    
    "pull_request")
        if [ "$ACTION" = "opened" ]; then
            # Run automated tests
            ./run-pr-tests.sh "$PR_NUMBER"
        fi
        ;;
esac
```

## Nginx Configuration

The nginx configuration proxies requests from HTTPS to the webhook service:

```nginx
location /hooks {
    proxy_pass http://localhost:9000;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Preserve GitHub webhook headers
    proxy_set_header X-GitHub-Event $http_x_github_event;
    proxy_set_header X-GitHub-Delivery $http_x_github_delivery;
    proxy_set_header X-Hub-Signature $http_x_hub_signature;
    proxy_set_header X-Hub-Signature-256 $http_x_hub_signature_256;
    
    # Increase timeout for webhook processing
    proxy_read_timeout 300s;
    proxy_connect_timeout 75s;
}
```

## Testing

### Send a Test Ping
```bash
gh api -X POST repos/OWNER/REPO/hooks/WEBHOOK_ID/pings
```

### Create Test Events
```bash
# Create a test repository
./create-test-repo.sh

# Trigger various events
./trigger-test-events.sh

# Clean up when done
./cleanup-test-repo.sh
```

### Local Testing
```python
# Use test-webhook.py for local testing
python3 test-webhook.py
```

## Management

### List Webhooks
```bash
./manage-webhook.sh
# Select option 1
```

### View Recent Deliveries
```bash
./manage-webhook.sh
# Select option 4
```

### Delete Webhook
```bash
./manage-webhook.sh
# Select option 5
```

## Troubleshooting

### Webhook Not Receiving Events
1. Check webhook service is running: `ps aux | grep webhook`
2. Verify nginx is configured: `sudo nginx -t`
3. Check webhook URL is accessible: `curl https://clidecoder.com/hooks/github-webhook`
4. Review GitHub webhook recent deliveries for errors

### Signature Validation Failed
1. Ensure secret in `hooks.json` matches GitHub webhook secret
2. Verify GitHub is using SHA256 (not SHA1)
3. Check for any proxy modifications to the payload

### Events Not Logging
1. Check script permissions: `ls -la handle-github-event.sh`
2. Verify log directory exists: `ls -la logs/`
3. Check webhook service logs for errors: `tail logs/webhook-service.log`

### Port 9000 Already in Use
```bash
# Find process using port 9000
sudo lsof -i :9000

# Kill the process if needed
sudo kill -9 <PID>
```

## Production Deployment

### Systemd Service
```bash
# Copy service file
sudo cp webhook.service /etc/systemd/system/

# Enable and start
sudo systemctl enable webhook
sudo systemctl start webhook

# Check status
sudo systemctl status webhook
```

### Log Rotation
Add to `/etc/logrotate.d/webhook`:
```
/home/clide/promptforge/webhook-config/logs/*.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
    create 0644 clide clide
}
```

### Monitoring
- Set up alerts for webhook service downtime
- Monitor log file sizes
- Track webhook delivery success rates
- Alert on repeated signature validation failures

## API Reference

### Webhook Payload
All events include:
- `X-GitHub-Event`: Event type (push, pull_request, etc.)
- `X-GitHub-Delivery`: Unique delivery ID
- `X-Hub-Signature-256`: HMAC signature
- JSON payload with event-specific data

### Environment Variables
Available in handler script:
- `GITHUB_REPO`: Repository full name
- `GITHUB_EVENT_TYPE`: Event type from header

### Script Arguments
1. Repository full name
2. Event type
3. Action (if applicable)
4. Full JSON payload

## Best Practices

1. **Security**
   - Rotate webhook secret regularly
   - Never log the webhook secret
   - Validate signatures for all events
   - Use HTTPS only

2. **Performance**
   - Process events asynchronously when possible
   - Set appropriate timeouts
   - Implement retry logic for failures
   - Archive old logs regularly

3. **Reliability**
   - Use systemd for automatic restarts
   - Monitor webhook service health
   - Set up redundancy if critical
   - Keep logs for audit trail

4. **Development**
   - Test with a dedicated test repository
   - Use the management scripts for debugging
   - Log extensively during development
   - Version control your handler scripts

## Support

For issues or questions:
- Check the troubleshooting section
- Review logs in `logs/` directory
- Test with the management scripts
- Verify GitHub webhook delivery status