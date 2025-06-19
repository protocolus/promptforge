# Migration from Bash to Python Webhook Handler

This guide helps you migrate from the bash-based webhook system to the new Python implementation.

## Overview

The Python version provides significant improvements:

- **Better Error Handling**: Proper exception handling and logging
- **Type Safety**: Pydantic models and type hints
- **Testing**: Unit tests and proper test infrastructure
- **Performance**: Async processing and better resource management
- **Monitoring**: Built-in health checks and statistics
- **Scalability**: Docker containerization and easy deployment

## Prerequisites

1. **Python 3.9+** installed
2. **Docker** (recommended) or Python virtual environment
3. **Environment variables** configured
4. **GitHub and Claude API access**

## Migration Steps

### 1. Backup Current System

```bash
# Backup bash webhook system
cd /home/clide/promptforge
cp -r webhook-config webhook-config.backup

# Backup any existing analyses
cp -r issues issues.backup
```

### 2. Setup Python Environment

```bash
cd /home/clide/promptforge/webhook-python

# Copy environment template
cp .env.example .env

# Edit .env with your credentials
nano .env
```

Required environment variables:
```bash
GITHUB_TOKEN=your_github_personal_access_token
GITHUB_WEBHOOK_SECRET=your_webhook_secret
ANTHROPIC_API_KEY=your_anthropic_api_key
```

### 3. Install Dependencies

#### Option A: Docker (Recommended)
```bash
# Start with Docker Compose
./scripts/start.sh
```

#### Option B: Python Virtual Environment
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
./scripts/start.sh
```

### 4. Update Webhook Configuration

#### GitHub Repository Settings
1. Go to your repository settings → Webhooks
2. Update the payload URL to: `http://your-server:9000/github-webhook`
3. Ensure the webhook secret matches your `.env` file
4. Verify events are configured: Issues, Pull Requests, Pull Request Reviews, Workflow runs

#### Test the Webhook
```bash
# Health check
curl http://localhost:9000/health

# Create a test issue to verify processing
gh issue create --repo your-repo/name \
  --title "Test Python webhook" \
  --body "Testing the new Python webhook system"
```

### 5. Stop Bash System

```bash
# Stop the bash webhook service
cd /home/clide/promptforge/webhook-config
ps aux | grep webhook
kill <webhook-pid>

# Stop the issue watcher if running
ps aux | grep issue_watcher
kill <issue-watcher-pid>
```

### 6. Verify Migration

Check that the Python system is working:

1. **Health Check**: `curl http://localhost:9000/health`
2. **Statistics**: `curl http://localhost:9000/stats`
3. **Logs**: Check `logs/webhook.log` for processing
4. **Outputs**: Verify files are created in `outputs/` directories

## Configuration Differences

### Bash vs Python Configuration

| Feature | Bash | Python |
|---------|------|--------|
| **Config** | Hardcoded variables | YAML + environment variables |
| **Prompts** | Hardcoded strings | Separate markdown files with templates |
| **Outputs** | Single `issues/` directory | Organized by event type |
| **Logging** | Simple echo to file | Structured JSON logging |
| **Health** | No health checks | Built-in health endpoints |

### Directory Structure Comparison

**Bash System:**
```
webhook-config/
├── handle-github-event.sh
├── prompts/
└── logs/
```

**Python System:**
```
webhook-python/
├── src/webhook_handler/
├── config/settings.yaml
├── prompts/
├── outputs/
│   ├── issues/
│   ├── pull_requests/
│   ├── reviews/
│   └── workflows/
└── logs/
```

## Feature Mapping

### Event Processing

| Event Type | Bash Support | Python Support | Notes |
|------------|--------------|----------------|-------|
| **Issues** | ✅ Full | ✅ Enhanced | Better label extraction |
| **Pull Requests** | ❌ Basic | ✅ Full | Comprehensive review |
| **PR Reviews** | ✅ Basic | ✅ Enhanced | Better context |
| **Workflows** | ❌ Logs only | ✅ Full | Failure analysis |
| **Releases** | ❌ Logs only | 🔄 Planned | Future feature |

### Analysis Features

| Feature | Bash | Python | Improvement |
|---------|------|--------|-------------|
| **Prompt Loading** | Hardcoded | File-based | Easy customization |
| **Label Extraction** | Regex | Smart parsing | More accurate |
| **Error Handling** | Basic | Comprehensive | Better reliability |
| **Rate Limiting** | None | Built-in | API protection |
| **Caching** | None | Prompt caching | Better performance |

## Troubleshooting Migration

### Common Issues

1. **Port Conflicts**
   ```bash
   # Check if port 9000 is in use
   sudo lsof -i :9000
   
   # Stop conflicting services
   sudo kill -9 <pid>
   ```

2. **Permission Issues**
   ```bash
   # Fix file permissions
   chmod +x scripts/*.sh
   chown -R $(whoami) logs/ outputs/
   ```

3. **Environment Variables Not Loading**
   ```bash
   # Verify .env file
   cat .env | grep -v '^#'
   
   # Test loading
   source .env && echo $GITHUB_TOKEN
   ```

4. **GitHub API Rate Limits**
   ```bash
   # Check rate limit status
   curl -H "Authorization: token $GITHUB_TOKEN" \
        https://api.github.com/rate_limit
   ```

### Validation Steps

Run these commands to verify successful migration:

```bash
# 1. Service is running
curl -f http://localhost:9000/health

# 2. Configuration is loaded
curl http://localhost:9000/stats | jq '.repositories'

# 3. Prompts are available
ls -la prompts/issues/

# 4. Test webhook processing
gh issue create --repo your-repo \
  --title "Migration Test" \
  --body "Testing Python webhook system"

# 5. Check processing logs
tail -f logs/webhook.log
```

## Rollback Plan

If you need to rollback to the bash system:

```bash
# 1. Stop Python webhook
./scripts/stop.sh

# 2. Restore bash system
cd /home/clide/promptforge/webhook-config
./start-webhook.sh

# 3. Update GitHub webhook URL back to original
# 4. Restart issue watcher if needed
```

## Performance Comparison

### Resource Usage

| Metric | Bash | Python | Improvement |
|--------|------|--------|-------------|
| **Memory** | ~50MB | ~100MB | More features |
| **CPU** | Variable | Consistent | Better optimization |
| **API Calls** | Many | Optimized | Rate limiting |
| **Error Recovery** | Poor | Excellent | Automatic retry |

### Processing Speed

- **Issue Analysis**: 5-10 seconds (similar)
- **PR Review**: N/A → 10-15 seconds (new feature)
- **Error Handling**: Manual → Automatic
- **Concurrent Processing**: Serial → Parallel

## Next Steps

After successful migration:

1. **Monitor Performance**: Check `/stats` endpoint regularly
2. **Customize Prompts**: Edit files in `prompts/` directory
3. **Setup Monitoring**: Configure health checks and alerts
4. **Scale if Needed**: Use Docker Compose for multi-instance deployment
5. **Backup**: Regular backup of `outputs/` and `config/`

## Support

For issues during migration:

1. Check logs: `tail -f logs/webhook.log`
2. Verify health: `curl http://localhost:9000/health`
3. Test GitHub connectivity: Use `/stats` endpoint
4. Review configuration: Check `config/settings.yaml`

The Python system maintains full compatibility with existing functionality while adding significant new capabilities and reliability improvements.