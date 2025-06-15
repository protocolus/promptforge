# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PromptForge is a fully implemented web-based prompt management system that stores LLM prompts as markdown files while using SQLite for indexing and search.

## Current Status

**IMPLEMENTED AND FUNCTIONAL** - The `/home/deluxified/promptforge/` directory contains a complete working application.

## Architecture

**Tech Stack:**
- Backend: Node.js with Express, SQLite database, file watching
- Frontend: React with Monaco editor, markdown preview
- Storage: Markdown files in `/prompts` directory (version controlled)
- Search: SQLite FTS5 for full-text search

**Key Features:**
- Real-time file watching and auto-indexing
- Full-text search across prompt content
- Category and tag-based organization
- Monaco editor with markdown preview
- Git-friendly markdown storage

## Development Commands

```bash
npm run install:all    # Install all dependencies
npm run init-db       # Initialize SQLite database
npm run dev          # Start both server and client
npm run dev:server   # Start only server (port 3001)
npm run dev:client   # Start only client (port 3000)
npm run build        # Build for production
npm start            # Start production server
```

## Project Structure

```
promptforge/
├── server/              # Express backend
│   ├── db/             # Database schema and connection
│   ├── routes/         # API routes (prompts, sync)
│   ├── services/       # File watching, indexing, I/O
│   ├── index.js        # Server entry point
│   └── package.json    # Server dependencies
├── client/             # React frontend
│   ├── src/
│   │   ├── components/ # UI components
│   │   ├── api/       # API client
│   │   ├── App.js     # Main application
│   │   └── App.css    # Dark theme styling
│   └── package.json   # Client dependencies
├── prompts/           # Markdown prompt files
│   ├── coding/       # Sample coding prompts
│   ├── debugging/    # Sample debugging prompts
│   └── README.md     # Prompt format guide
├── package.json      # Root scripts
├── README.md         # Project documentation
└── promptforge.db    # SQLite database (auto-created)
```

## API Endpoints

- `GET /api/prompts` - Search and filter prompts
- `POST /api/prompts` - Create new prompt
- `PUT /api/prompts/:id` - Update prompt
- `DELETE /api/prompts/:id` - Delete prompt
- `GET /api/prompts/meta/categories` - Get categories
- `POST /api/sync/reindex` - Manual reindex

## Key Implementation Features

- **Auto-indexing**: Files are automatically indexed on creation/modification
- **Full-text search**: SQLite FTS5 provides fast content search
- **Real-time updates**: File watcher detects changes and updates index
- **Git integration**: Only markdown files are tracked, database is ignored
- **Dark theme**: GitHub-inspired dark theme for the UI
- **Monaco editor**: Professional code editor with markdown highlighting