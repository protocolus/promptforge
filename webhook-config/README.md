# GitHub Webhook Configuration

This directory contains the configuration for receiving GitHub webhooks for all events.

## Setup Instructions

### 1. Configure the Secret

Edit `hooks.json` and replace `your-secret-here` with a strong secret:

```bash
# Generate a random secret
openssl rand -hex 32
```

### 2. Start the Webhook Service

#### Option A: Run directly
```bash
./start-webhook.sh
```

#### Option B: Run with custom port
```bash
PORT=8080 ./start-webhook.sh
```

#### Option C: Install as systemd service (recommended for production)
```bash
# Copy service file
sudo cp webhook.service /etc/systemd/system/

# Edit the service file if needed (change user, paths, etc)
sudo systemctl edit webhook.service

# Enable and start the service
sudo systemctl enable webhook
sudo systemctl start webhook

# Check status
sudo systemctl status webhook

# View logs
sudo journalctl -u webhook -f
```

### 3. Configure Nginx (for HTTPS)

To use HTTPS with clidecoder.com, run:

```bash
sudo ./update-nginx.sh
```

This will configure nginx to proxy requests from `https://clidecoder.com/hooks` to the webhook service.

### 4. Configure GitHub Repository

#### Option A: Using GitHub CLI (Recommended)
```bash
# First authenticate with GitHub CLI
gh auth login

# Then run the setup script
./setup-github-webhook.sh
```

This script will:
- Generate a secure secret automatically
- Create the webhook via GitHub API
- Configure it to receive all events
- Send a test ping

#### Option B: Manual Configuration
1. Go to your GitHub repository settings
2. Navigate to "Webhooks" → "Add webhook"
3. Configure:
   - **Payload URL**: `https://clidecoder.com/hooks/github-webhook`
   - **Content type**: `application/json`
   - **Secret**: Use the same secret from `hooks.json`
   - **Events**: Select "Send me everything" for all events
4. Click "Add webhook"

#### Managing the Webhook
Use the management script to list, test, or delete webhooks:
```bash
./manage-webhook.sh
```

### 5. Test the Webhook

GitHub will send a ping event immediately after creating the webhook. Check the logs:

```bash
tail -f webhook-config/logs/github-events-*.log
```

## Documentation

- **[WEBHOOK-SETUP-GUIDE.md](WEBHOOK-SETUP-GUIDE.md)** - Complete setup and configuration guide
- **[INTEGRATION-EXAMPLES.md](INTEGRATION-EXAMPLES.md)** - Practical integration examples and workflows
- **[DEPLOYMENT-CHECKLIST.md](DEPLOYMENT-CHECKLIST.md)** - Production deployment checklist

## Files Overview

- `hooks.json` - Webhook configuration
- `handle-github-event.sh` - Script that processes GitHub events
- `start-webhook.sh` - Convenience script to start the webhook service
- `setup-github-webhook.sh` - Automated GitHub webhook setup via API
- `manage-webhook.sh` - Webhook management and testing tool
- `webhook.service` - Systemd service file for production deployment
- `logs/` - Directory containing event logs and service logs

## Event Handling

The `handle-github-event.sh` script currently:
- Logs all incoming events with timestamps
- Parses specific event types (push, pull_request, issues, release, workflow_run)
- Can be extended with custom logic for each event type

To add custom actions, edit the script and add your logic in the appropriate case statements.

## Security Notes

1. **Always use HTTPS in production** - Consider using a reverse proxy (nginx/Apache) with SSL
2. **Keep your webhook secret secure** - Never commit it to version control
3. **Validate payloads** - The webhook tool validates HMAC signatures automatically
4. **Restrict access** - Use firewall rules to limit access to the webhook port

## Troubleshooting

1. **Webhook not receiving events**
   - Check firewall rules (port 9000 must be accessible)
   - Verify the webhook URL in GitHub settings
   - Check webhook service logs

2. **Signature validation failing**
   - Ensure the secret in `hooks.json` matches GitHub exactly
   - Check that GitHub is using SHA256 (default for new webhooks)

3. **Script not executing**
   - Verify script permissions (`chmod +x`)
   - Check script path in `hooks.json`
   - Look for errors in webhook service logs