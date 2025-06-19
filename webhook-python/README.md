# GitHub Webhook Handler with Claude Code Integration

A robust, Python-based webhook handler that automatically analyzes GitHub events using Claude Code AI, providing intelligent insights for issues, pull requests, code reviews, and workflow failures.

## Features

- 🤖 **AI-Powered Analysis**: Comprehensive analysis using Claude AI
- 🔄 **Multi-Event Support**: Issues, PRs, reviews, workflows
- 📝 **Modular Prompts**: Customizable prompt templates
- 🏷️ **Smart Labeling**: Automatic GitHub label application
- 📊 **Statistics & Monitoring**: Built-in health checks and metrics
- 🐳 **Docker Ready**: Containerized deployment
- 🔒 **Secure**: Webhook signature validation
- ⚡ **Async Processing**: High-performance event handling

## Quick Start

### 1. Setup

```bash
git clone <repository>
cd webhook-python
cp .env.example .env
# Edit .env with your API keys
```

### 2. Configure Environment

```bash
# Required environment variables
GITHUB_TOKEN=your_github_token
GITHUB_WEBHOOK_SECRET=your_webhook_secret
ANTHROPIC_API_KEY=your_claude_api_key
```

### 3. Start the Service

```bash
# With Docker (recommended)
./scripts/start.sh

# Or manually
python -m uvicorn webhook_handler.main:app --host 0.0.0.0 --port 9000
```

### 4. Configure GitHub Webhook

1. Go to your repository settings → Webhooks
2. Add webhook: `http://your-server:9000/github-webhook`
3. Select events: Issues, Pull Requests, Reviews, Workflows
4. Add your webhook secret

## Architecture

```
GitHub Event → FastAPI → Event Router → Specific Handler → Claude AI → GitHub Comment/Labels
```

### Components

- **FastAPI Server**: Receives and validates webhooks
- **Event Handlers**: Process different GitHub events
- **Claude Client**: Integrates with Anthropic's Claude AI
- **GitHub Client**: Manages GitHub API interactions
- **Prompt System**: Loads and renders analysis templates

## Event Types Supported

### Issues (`issues`)
- **Events**: `opened`, `edited`
- **Analysis**: Viability check, classification, implementation planning
- **Actions**: Label application, comment posting, auto-closing

### Pull Requests (`pull_request`)
- **Events**: `opened`, `synchronize`
- **Analysis**: Code quality review, architecture assessment
- **Actions**: Review comments, size/type labeling

### PR Reviews (`pull_request_review`)
- **Events**: Review requests
- **Analysis**: Detailed code review with security focus
- **Actions**: Comprehensive review comments

### Workflows (`workflow_run`)
- **Events**: `completed` (failures)
- **Analysis**: Failure analysis, resolution recommendations
- **Actions**: Analysis comments on related PRs

## Configuration

### Repository Configuration (`config/settings.yaml`)

```yaml
repositories:
  - name: "owner/repo"
    events:
      - "issues"
      - "pull_request"
      - "pull_request_review"
    settings:
      auto_close_invalid: true
      post_analysis_comments: true
      apply_labels: true
```

### Prompt Templates (`prompts/`)

```
prompts/
├── issues/new_issue.md
├── pull_requests/new_pr.md
├── reviews/pr_review_requested.md
└── workflows/workflow_failed.md
```

## API Endpoints

- `GET /health` - Health check
- `POST /github-webhook` - GitHub webhook receiver
- `GET /stats` - Processing statistics

## Docker Deployment

### Development
```bash
docker-compose up -d
```

### Production
```bash
docker-compose --profile production up -d
```

## Monitoring

### Health Check
```bash
curl http://localhost:9000/health
```

### Statistics
```bash
curl http://localhost:9000/stats
```

## Customization

### Adding New Event Types

1. **Create Handler**:
   ```python
   class NewEventHandler(BaseHandler):
       async def handle(self, payload, action):
           # Implementation
   ```

2. **Add to Registry**:
   ```python
   HANDLERS["new_event"] = NewEventHandler
   ```

3. **Create Prompt Template**:
   ```bash
   mkdir prompts/new_event
   echo "Analysis prompt..." > prompts/new_event/action.md
   ```

### Customizing Prompts

Edit files in `prompts/` directory:
- Use Jinja2 templating for dynamic content
- Variables available: `{{issue_title}}`, `{{pr_number}}`, etc.
- Restart not required - prompts reload automatically

## Development

### Setup Development Environment
```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install -e .[dev]
```

### Running Tests
```bash
pytest tests/
```

### Code Quality
```bash
black src/
isort src/
mypy src/
```

## Troubleshooting

### Common Issues

1. **Webhook Not Receiving Events**
   - Check GitHub webhook configuration
   - Verify URL is accessible
   - Check webhook secret

2. **Analysis Not Posted**
   - Verify GitHub token permissions
   - Check repository configuration
   - Review error logs

3. **Claude API Errors**
   - Verify API key
   - Check rate limits
   - Review prompt content

### Debugging

```bash
# View logs
tail -f logs/webhook.log

# Check statistics
curl http://localhost:9000/stats

# Test webhook locally
curl -X POST http://localhost:9000/github-webhook \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

## Performance

### Benchmarks
- **Issue Analysis**: ~5-8 seconds
- **PR Review**: ~8-12 seconds
- **Concurrent Events**: 10+ per minute
- **Memory Usage**: ~100MB base

### Optimization Tips
- Use Docker for consistent performance
- Enable async processing for high volume
- Monitor Claude API rate limits
- Configure appropriate timeouts

## Security

- ✅ Webhook signature validation
- ✅ Environment variable secrets
- ✅ Rate limiting
- ✅ Input validation
- ✅ Non-root Docker containers

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create feature branch
3. Add tests for new functionality
4. Submit pull request

## Support

- 📖 Documentation: See `/docs` directory
- 🐛 Issues: GitHub Issues
- 💬 Discussions: GitHub Discussions