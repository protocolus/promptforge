# PromptForge

A web-based prompt management system that stores LLM prompts as markdown files in your repository while using SQLite for fast searching and indexing.

## Features

- 📝 Store prompts as version-controlled markdown files
- 🔍 Fast full-text search using SQLite FTS5
- 🏷️ Organize prompts with categories and tags
- 📊 Track prompt versions and modifications
- 🔄 Automatic file watching and index synchronization
- 🚀 Web-based editor with syntax highlighting
- 💾 Git-friendly storage format

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/protocolus/promptforge.git
   cd promptforge
   ```

2. Install dependencies:
   ```bash
   npm run install:all
   ```

3. Initialize the database:
   ```bash
   npm run init-db
   ```

4. Start the development servers:
   ```bash
   npm run dev
   ```

5. Open http://localhost:3000 in your browser

## Project Structure

- `/prompts` - Markdown files for all prompts (tracked in git)
- `/server` - Express.js backend API
- `/client` - React frontend application
- `promptforge.db` - SQLite database (in .gitignore)

## How It Works

1. Create and edit prompts through the web interface
2. Prompts are saved as markdown files in the `/prompts` directory
3. SQLite indexes these files for fast searching
4. Changes to files are automatically detected and reindexed
5. Push your `/prompts` directory to git to share with your team

## Prompt File Format

```markdown
---
title: Your Prompt Title
model: claude-3-opus
tags: [tag1, tag2]
created: 2024-03-15
version: 1.0
---

# Your Prompt Title

Your prompt content goes here...
```

## Development Commands

- `npm run dev` - Start both server and client in development mode
- `npm run dev:server` - Start only the server
- `npm run dev:client` - Start only the client
- `npm run build` - Build the client for production
- `npm start` - Start the server in production mode
- `npm run init-db` - Initialize the SQLite database

## API Endpoints

### Prompts
- `GET /api/prompts` - Get all prompts with optional search/filter
- `GET /api/prompts/:id` - Get single prompt
- `POST /api/prompts` - Create new prompt
- `PUT /api/prompts/:id` - Update prompt
- `DELETE /api/prompts/:id` - Delete prompt
- `GET /api/prompts/meta/categories` - Get categories with counts

### Sync
- `POST /api/sync/reindex` - Manually trigger full reindex

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the ISC License - see the [LICENSE](LICENSE) file for details.

## Support

- 📚 [Documentation](https://github.com/protocolus/promptforge/wiki)
- 🐛 [Issue Tracker](https://github.com/protocolus/promptforge/issues)
- 💬 [Discussions](https://github.com/protocolus/promptforge/discussions)