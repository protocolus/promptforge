# Prompts Directory

This directory contains all your prompt files organized by category.

## Structure

```
prompts/
├── coding/
│   ├── refactor-to-functional.md
│   └── generate-unit-tests.md
├── debugging/
│   └── explain-error.md
└── documentation/
    └── generate-readme.md
```

## Creating New Prompts

You can create prompts either through the web interface or by manually adding markdown files to this directory. The system will automatically detect and index new files.

## Frontmatter Schema

Each prompt file should include frontmatter with the following fields:

- `title` (required): The display name of the prompt
- `model` (optional): The LLM model this prompt is optimized for
- `tags` (optional): Array of tags for categorization
- `created` (optional): Creation date (YYYY-MM-DD)
- `version` (optional): Version number

Example:
```yaml
---
title: Generate Unit Tests
model: claude-3-opus
tags: [testing, javascript, jest]
created: 2024-03-15
version: 1.0
---
```