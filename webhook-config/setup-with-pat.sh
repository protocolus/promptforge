#!/bin/bash

# Quick setup script for GitHub CLI with PAT

echo "GitHub CLI Authentication with Personal Access Token"
echo "==================================================="
echo ""
echo "You can authenticate using one of these methods:"
echo ""
echo "1. Interactive (paste token when prompted):"
echo "   gh auth login --with-token"
echo ""
echo "2. From environment variable:"
echo "   export GITHUB_TOKEN='your-pat-here'"
echo "   gh auth login --with-token <<< \$GITHUB_TOKEN"
echo ""
echo "3. From file:"
echo "   echo 'your-pat-here' > ~/.github-token"
echo "   gh auth login --with-token < ~/.github-token"
echo "   rm ~/.github-token  # Delete after use"
echo ""
echo "After authentication, run:"
echo "   ./setup-github-webhook.sh"
echo ""
echo "Your PAT needs these scopes: repo (for private repos) or public_repo (for public repos)"