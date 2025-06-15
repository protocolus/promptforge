# GitHub Publishing Guide for PromptForge

This guide helps Claude Code in the promptforge directory publish changes to GitHub.

## Prerequisites Check

Run these commands to verify GitHub publishing capabilities:

```bash
# Check if GitHub CLI is installed
gh --version

# Check authentication status
gh auth status

# If not authenticated, run:
gh auth login

# Verify git remote configuration
git remote -v
```

## Publishing Workflow

### 1. Standard Git Push
```bash
# Add changes
git add .

# Commit with descriptive message
git commit -m "Description of changes"

# Push to main branch
git push origin main
```

### 2. Create Pull Request
```bash
# Create and push feature branch
git checkout -b feature-name
git add .
git commit -m "Feature description"
git push -u origin feature-name

# Create PR using GitHub CLI
gh pr create --title "Feature title" --body "Description of changes"
```

### 3. Release Publishing
```bash
# Create and push tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# Create GitHub release
gh release create v1.0.0 --title "v1.0.0" --notes "Release notes"
```

## Common Issues and Solutions

### Authentication Problems
```bash
# Re-authenticate if needed
gh auth logout
gh auth login --with-token < your-token-file
```

### Push Permission Denied
```bash
# Check if you're using correct remote URL
git remote set-url origin git@github.com:protocolus/promptforge.git
```

### CI/CD Integration
The repository has automated CI that runs on:
- Pushes to `main` and `develop` branches  
- Pull requests to `main` branch

Tests will run automatically and must pass before merging.

## CLAUDE.md Integration

Add these commands to your CLAUDE.md for automated workflows:

```markdown
### Publishing Commands
```bash
# Quick publish to main
git add . && git commit -m "Update: [description]" && git push origin main

# Create feature PR  
git checkout -b feature-name && git add . && git commit -m "Add: [description]" && git push -u origin feature-name && gh pr create --title "[title]" --body "[description]"
```
```

This ensures Claude Code can easily publish changes using standard git and GitHub CLI commands.