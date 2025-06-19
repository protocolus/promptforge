# Modular Prompt System for GitHub Webhooks

This guide documents the modular prompt system that organizes different Claude prompts for various GitHub events, making them easier to maintain and customize.

## Overview

Instead of hardcoding prompts in the webhook handler script, the system now loads prompts from separate markdown files organized by event type. This approach provides:

- **Maintainability**: Easy to update prompts without touching code
- **Organization**: Clear separation of concerns
- **Customization**: Event-specific prompts for better analysis
- **Version Control**: Track prompt changes over time
- **Reusability**: Share prompts across different projects

## Directory Structure

```
webhook-config/prompts/
├── issues/
│   ├── new_issue.md           # Analysis for newly created issues
│   └── issue_updated.md       # Analysis for updated issues (future)
├── pull_requests/
│   ├── new_pr.md             # Analysis for new pull requests
│   ├── pr_updated.md         # Analysis for updated PRs
│   └── pr_merged.md          # Analysis for merged PRs (future)
├── reviews/
│   ├── pr_review_requested.md # Analysis when review is requested
│   └── review_submitted.md    # Analysis of submitted reviews (future)
├── releases/
│   ├── new_release.md        # Analysis for new releases
│   └── pre_release.md        # Analysis for pre-releases (future)
└── workflows/
    ├── workflow_failed.md    # Analysis for failed workflows
    └── workflow_success.md   # Analysis for successful workflows (future)
```

## Event-to-Prompt Mapping

| GitHub Event | Action | Prompt File | Output Directory |
|--------------|--------|-------------|------------------|
| `issues` | `opened` | `issues/new_issue.md` | `issues/` |
| `pull_request` | `opened` | `pull_requests/new_pr.md` | `pull_requests/` |
| `pull_request` | `synchronize` | `pull_requests/pr_updated.md` | `pull_requests/` |
| `pull_request_review_requested` | - | `reviews/pr_review_requested.md` | `reviews/` |
| `workflow_run` | `completed` (failed) | `workflows/workflow_failed.md` | `workflows/` |
| `release` | `published` | `releases/new_release.md` | `releases/` |

## Using the Modular System

### 1. Switch to Modular Handler

Replace the existing webhook handler with the modular version:

```bash
cd /home/clide/promptforge/webhook-config

# Backup current handler
cp handle-github-event.sh handle-github-event.sh.backup

# Use modular handler
cp handle-github-event-modular.sh handle-github-event.sh

# Update hooks.json to use new handler
# (Should already point to handle-github-event.sh)
```

### 2. Restart Webhook Service

```bash
# Stop current service
ps aux | grep webhook
kill [PID]

# Start with new handler
./start-webhook.sh
```

### 3. Test the System

```bash
# Test issue analysis
./test-issue-webhook.sh

# Create a test PR
gh pr create --repo protocolus/promptforge \
  --title "Test PR for webhook" \
  --body "Testing modular prompt system"

# Monitor logs
tail -f logs/github-events-*.log
```

## Customizing Prompts

### Editing Existing Prompts

```bash
# Edit issue analysis prompt
nano prompts/issues/new_issue.md

# Edit PR review prompt
nano prompts/pull_requests/new_pr.md

# Changes take effect immediately - no restart needed
```

### Adding New Event Types

1. **Create prompt file**:
   ```bash
   mkdir -p prompts/new_event_type
   nano prompts/new_event_type/event_action.md
   ```

2. **Update webhook handler**:
   Add case handling in `handle-github-event-modular.sh`:
   ```bash
   "new_event_type")
       if [ "$ACTION" = "event_action" ]; then
           process_new_event "$EVENT_DATA"
       fi
       ;;
   ```

3. **Add processing function**:
   ```bash
   process_new_event() {
       local event_data="$1"
       local prompt_file="${PROMPT_DIR}/new_event_type/event_action.md"
       local output_file="/path/to/output/file.md"
       
       process_with_claude "new_event" "$event_data" "$prompt_file" "$output_file"
   }
   ```

### Creating Event-Specific Outputs

Each event type gets its own output directory:

```bash
# Issue analysis
/home/clide/promptforge/issues/issue_123_analysis.md

# PR review
/home/clide/promptforge/pull_requests/pr_456_analysis.md

# Code review
/home/clide/promptforge/reviews/pr_456_review_1234567890.md

# Workflow analysis
/home/clide/promptforge/workflows/workflow_789_analysis.md
```

## Available Prompt Templates

### Issues (`issues/new_issue.md`)
- Viability check (spam detection)
- Issue classification
- GitHub labeling suggestions
- Implementation planning
- Impact assessment

### Pull Requests (`pull_requests/new_pr.md`)
- Code quality review
- Architecture assessment
- Testing evaluation
- Documentation check
- Merge recommendation

### Reviews (`reviews/pr_review_requested.md`)
- Line-by-line code review
- Security assessment
- Performance analysis
- Integration concerns
- Specific feedback with examples

### Workflows (`workflows/workflow_failed.md`)
- Failure identification
- Root cause analysis
- Resolution steps
- Workaround options
- Prevention recommendations

## Advanced Configuration

### Environment Variables

```bash
# Enable payload saving for debugging
export SAVE_PAYLOADS=true

# Custom prompt directory
export PROMPT_DIR="/custom/path/to/prompts"
```

### Dynamic Prompt Selection

You can customize prompt selection based on repository, user, or other criteria by modifying the `load_prompt()` function:

```bash
load_prompt() {
    local base_prompt="$1"
    local repo_specific="${base_prompt%.md}_${REPO_NAME//\//_}.md"
    
    # Try repo-specific prompt first
    if [ -f "$repo_specific" ]; then
        cat "$repo_specific"
    elif [ -f "$base_prompt" ]; then
        cat "$base_prompt"
    else
        echo "Error: No prompt found"
        return 1
    fi
}
```

### Conditional Processing

Enable/disable certain event types with configuration:

```bash
# At top of handle-github-event-modular.sh
PROCESS_ISSUES=${PROCESS_ISSUES:-true}
PROCESS_PRS=${PROCESS_PRS:-true}
PROCESS_REVIEWS=${PROCESS_REVIEWS:-true}
PROCESS_WORKFLOWS=${PROCESS_WORKFLOWS:-false}

# In event handling
if [ "$PROCESS_ISSUES" = "true" ] && [ "$EVENT_TYPE" = "issues" ]; then
    # Process issues
fi
```

## Monitoring and Debugging

### Check Prompt Loading

```bash
# Test prompt loading
cd /home/clide/promptforge/webhook-config
source handle-github-event-modular.sh
load_prompt "prompts/issues/new_issue.md"
```

### View Event Processing

```bash
# Monitor all events
tail -f logs/github-events-*.log

# Filter specific event types
grep "Processing.*issue" logs/github-events-*.log
grep "Processing.*PR" logs/github-events-*.log
```

### Debug Failed Processing

```bash
# Check for missing prompts
find prompts/ -name "*.md" -type f

# Verify Claude CLI works
echo "Test prompt" | claude -p

# Check file permissions
ls -la prompts/issues/new_issue.md
```

## Best Practices

### 1. Prompt Design
- Keep prompts focused and specific to event type
- Use clear step-by-step instructions
- Include examples where helpful
- Define expected output format

### 2. Version Control
```bash
# Track prompt changes
git add prompts/
git commit -m "Update PR review prompt for better security analysis"

# Use branches for major prompt changes
git checkout -b improve-issue-analysis
# Edit prompts
git commit -m "Enhanced issue analysis with risk assessment"
```

### 3. Testing
```bash
# Test prompts before deploying
./test-issue-webhook.sh
./test-pr-webhook.sh

# Use test repository for experimentation
REPO="test-org/test-repo" ./handle-github-event-modular.sh
```

### 4. Performance
- Keep prompts concise but comprehensive
- Limit diff size for PR analysis (currently 1000-2000 lines)
- Monitor Claude API usage and costs

### 5. Security
- Don't include sensitive information in prompts
- Review prompts that might be logged
- Be cautious with automatic actions (closing issues, etc.)

## Migration from Hardcoded Prompts

### 1. Extract Current Prompts
```bash
# Copy existing prompt text to files
grep -A 50 "CLAUDE_PROMPT=" issue_watcher.sh > prompts/issues/new_issue.md
```

### 2. Test Equivalence
```bash
# Run both systems in parallel initially
# Compare outputs to ensure consistency
```

### 3. Gradual Migration
1. Start with issues only
2. Add PR support
3. Add review functionality
4. Add workflow analysis

## Troubleshooting

### Prompt Not Found
```
ERROR: Prompt file not found: prompts/issues/new_issue.md
```
**Solution**: Verify file exists and has correct permissions

### Claude Analysis Failed
```
ERROR: Claude analysis failed
```
**Solutions**:
- Check Claude CLI is working: `echo "test" | claude -p`
- Verify prompt syntax is valid
- Check system resources and API limits

### No Analysis Posted
**Check**:
- GitHub CLI authentication: `gh auth status`
- Repository permissions
- Webhook logs for errors

The modular prompt system provides a flexible, maintainable way to handle different GitHub events with specialized analysis prompts tailored to each event type.