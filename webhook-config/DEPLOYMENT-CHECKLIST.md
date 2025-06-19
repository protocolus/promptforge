# GitHub Webhook Deployment Checklist

Use this checklist to ensure a complete and secure webhook deployment.

## Pre-Deployment Setup

### [ ] System Requirements
- [ ] Linux server with nginx installed
- [ ] `webhook` tool installed (`sudo apt install webhook` or download from GitHub)
- [ ] GitHub CLI installed and configured (`gh` command)
- [ ] Required packages: `jq`, `curl`, `openssl`
- [ ] SSL certificate configured for domain (Let's Encrypt recommended)

### [ ] Security Setup
- [ ] Generate secure webhook secret: `openssl rand -hex 32`
- [ ] Store secret securely (not in version control)
- [ ] Configure firewall to allow ports 80, 443, and restrict port 9000 to localhost
- [ ] Ensure webhook runs as non-root user

### [ ] Directory Structure
```bash
mkdir -p /home/clide/promptforge/webhook-config/logs
chmod 755 /home/clide/promptforge/webhook-config
chmod 644 /home/clide/promptforge/webhook-config/*.json
chmod 755 /home/clide/promptforge/webhook-config/*.sh
```

## Configuration Files

### [ ] hooks.json
- [ ] Update webhook secret
- [ ] Verify script paths are absolute
- [ ] Test JSON syntax: `jq . hooks.json`

### [ ] handle-github-event.sh
- [ ] Set executable permissions: `chmod +x handle-github-event.sh`
- [ ] Test script syntax: `bash -n handle-github-event.sh`
- [ ] Customize event handling for your needs
- [ ] Add error handling for external commands

### [ ] Nginx Configuration
- [ ] Backup existing nginx config
- [ ] Run nginx configuration updater: `sudo ./update-nginx.sh`
- [ ] Test nginx config: `sudo nginx -t`
- [ ] Reload nginx: `sudo systemctl reload nginx`

## Service Setup

### [ ] Webhook Service
- [ ] Test webhook service manually: `./start-webhook.sh`
- [ ] Verify port 9000 is listening: `netstat -tlnp | grep 9000`
- [ ] Test webhook endpoint: `curl http://localhost:9000/hooks/github-webhook`

### [ ] Systemd Service (Production)
- [ ] Copy service file: `sudo cp webhook.service /etc/systemd/system/`
- [ ] Edit service file paths if needed
- [ ] Enable service: `sudo systemctl enable webhook`
- [ ] Start service: `sudo systemctl start webhook`
- [ ] Check service status: `sudo systemctl status webhook`

## Testing

### [ ] Local Testing
- [ ] Run local webhook tests: `python3 test-webhook.py`
- [ ] Verify signature validation works
- [ ] Check event logging: `tail -f logs/github-events-*.log`

### [ ] External Testing
- [ ] Test HTTPS endpoint: `curl -I https://clidecoder.com/hooks/github-webhook`
- [ ] Create test repository: `./create-test-repo.sh`
- [ ] Trigger test events: `./trigger-test-events.sh`
- [ ] Verify events are received and logged

### [ ] GitHub Integration
- [ ] Configure webhook on test repository
- [ ] Send manual ping: `gh api -X POST repos/OWNER/REPO/hooks/ID/pings`
- [ ] Verify ping appears in logs
- [ ] Test actual events (push, issues, PRs)

## Security Validation

### [ ] HTTPS Configuration
- [ ] Verify SSL certificate is valid
- [ ] Test with SSL Labs: https://www.ssllabs.com/ssltest/
- [ ] Ensure HTTP redirects to HTTPS

### [ ] Webhook Security
- [ ] Verify signature validation is working
- [ ] Test with invalid signature (should fail)
- [ ] Check webhook service logs for signature validation

### [ ] Access Control
- [ ] Webhook service only listens on localhost
- [ ] Port 9000 not accessible externally
- [ ] Log files have appropriate permissions

## Monitoring Setup

### [ ] Log Management
- [ ] Set up log rotation
- [ ] Configure log aggregation (if needed)
- [ ] Set up log monitoring/alerting

### [ ] Service Monitoring
- [ ] Monitor webhook service uptime
- [ ] Monitor nginx status
- [ ] Set up disk space monitoring for logs

### [ ] Application Monitoring
- [ ] Monitor webhook delivery success rates
- [ ] Set up alerts for repeated failures
- [ ] Monitor processing times

## Documentation

### [ ] Internal Documentation
- [ ] Document webhook endpoints and purposes
- [ ] Create runbook for common issues
- [ ] Document emergency procedures

### [ ] Team Knowledge
- [ ] Share webhook configuration with team
- [ ] Document custom event handlers
- [ ] Create troubleshooting guide

## Production Deployment

### [ ] Deployment Process
- [ ] Stop existing webhook service
- [ ] Deploy new configuration files
- [ ] Update nginx configuration
- [ ] Start webhook service
- [ ] Verify everything is working

### [ ] Rollback Plan
- [ ] Backup current configuration
- [ ] Document rollback procedure
- [ ] Test rollback process

### [ ] Post-Deployment
- [ ] Monitor logs for 24 hours
- [ ] Verify all expected events are received
- [ ] Check webhook delivery success rates on GitHub

## Repository Configuration

### [ ] Webhook Setup
- [ ] Configure webhook URL: `https://clidecoder.com/hooks/github-webhook`
- [ ] Set content type to `application/json`
- [ ] Configure webhook secret
- [ ] Select events to send (recommend "Send me everything")

### [ ] Initial Testing
- [ ] Create test issue
- [ ] Make test commit
- [ ] Create test pull request
- [ ] Verify all events are received

## Maintenance

### [ ] Regular Tasks
- [ ] Rotate webhook secrets every 90 days
- [ ] Update webhook tool when new versions available
- [ ] Clean up old log files
- [ ] Review and update event handlers

### [ ] Health Checks
- [ ] Weekly: Check service status and logs
- [ ] Monthly: Review webhook delivery success rates
- [ ] Quarterly: Security review and updates

## Troubleshooting Quick Reference

### Service Not Starting
```bash
sudo systemctl status webhook
sudo journalctl -u webhook -f
```

### Events Not Received
```bash
# Check webhook service
ps aux | grep webhook
netstat -tlnp | grep 9000

# Check nginx
sudo nginx -t
sudo systemctl status nginx

# Check GitHub webhook deliveries
gh api repos/OWNER/REPO/hooks/ID/deliveries
```

### Signature Validation Errors
```bash
# Check webhook secret matches
grep secret hooks.json
# Compare with GitHub webhook settings

# Test signature locally
python3 test-webhook.py
```

## Security Incident Response

### [ ] Compromise Response
- [ ] Immediately rotate webhook secret
- [ ] Review logs for suspicious activity
- [ ] Update GitHub webhook with new secret
- [ ] Monitor for unusual patterns

### [ ] Regular Security Tasks
- [ ] Review webhook access logs
- [ ] Update webhook tool and dependencies
- [ ] Check for security advisories
- [ ] Audit webhook permissions

## Backup and Recovery

### [ ] Configuration Backup
- [ ] Backup `hooks.json` (without secret)
- [ ] Backup custom handler scripts
- [ ] Backup nginx configuration
- [ ] Document webhook secret storage location

### [ ] Log Backup
- [ ] Archive old event logs
- [ ] Backup important events database
- [ ] Document log retention policy

## Performance Optimization

### [ ] Resource Monitoring
- [ ] Monitor CPU usage during high event volumes
- [ ] Monitor memory usage
- [ ] Monitor disk I/O for log writes

### [ ] Optimization Tasks
- [ ] Optimize event handler scripts
- [ ] Implement async processing for slow operations
- [ ] Configure appropriate nginx timeouts
- [ ] Set up event queuing if needed

## Compliance and Auditing

### [ ] Audit Trail
- [ ] Log all webhook events with timestamps
- [ ] Maintain access logs
- [ ] Document all configuration changes

### [ ] Data Protection
- [ ] Ensure webhook payloads don't contain sensitive data
- [ ] Implement log sanitization if needed
- [ ] Document data retention policies

---

## Final Verification

### [ ] End-to-End Test
1. Create test repository
2. Configure webhook
3. Generate various event types
4. Verify all events are processed correctly
5. Check error handling works properly
6. Confirm monitoring and alerting is active

### [ ] Sign-off
- [ ] Technical review completed
- [ ] Security review completed
- [ ] Documentation updated
- [ ] Team trained on new system
- [ ] Monitoring and alerts configured
- [ ] Deployment approved

**Deployment Date:** ___________  
**Deployed By:** ___________  
**Reviewed By:** ___________