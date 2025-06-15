# PromptForge Project Structure

## Project Overview
A web-based prompt management system that stores prompts as markdown files in the repository while using SQLite for fast searching and indexing.

## Directory Structure
```
promptforge/
├── server/
│   ├── index.js
│   ├── db/
│   │   ├── database.js
│   │   └── schema.sql
│   ├── routes/
│   │   ├── prompts.js
│   │   └── sync.js
│   ├── services/
│   │   ├── fileService.js
│   │   ├── indexService.js
│   │   └── watchService.js
│   └── package.json
├── client/
│   ├── src/
│   │   ├── App.js
│   │   ├── components/
│   │   │   ├── PromptEditor.js
│   │   │   ├── PromptList.js
│   │   │   └── SearchBar.js
│   │   └── api/
│   │       └── prompts.js
│   ├── public/
│   └── package.json
├── prompts/
│   └── README.md
├── .gitignore
├── package.json
└── README.md
```

## Backend Implementation

### server/package.json
```json
{
  "name": "promptforge-server",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "init-db": "node db/database.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "sqlite3": "^5.1.6",
    "gray-matter": "^4.0.3",
    "chokidar": "^3.5.3",
    "multer": "^1.4.5-lts.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
```

### server/index.js
```javascript
import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';
import promptRoutes from './routes/prompts.js';
import syncRoutes from './routes/sync.js';
import { initDatabase } from './db/database.js';
import { watchPromptFiles } from './services/watchService.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// Initialize database
await initDatabase();

// Start file watcher
watchPromptFiles();

// Routes
app.use('/api/prompts', promptRoutes);
app.use('/api/sync', syncRoutes);

app.listen(PORT, () => {
  console.log(`PromptForge server running on port ${PORT}`);
});
```

### server/db/database.js
```javascript
import sqlite3 from 'sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs/promises';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dbPath = path.join(__dirname, '../../promptforge.db');

export const db = new sqlite3.Database(dbPath);

export async function initDatabase() {
  const schema = await fs.readFile(path.join(__dirname, 'schema.sql'), 'utf-8');
  
  return new Promise((resolve, reject) => {
    db.exec(schema, (err) => {
      if (err) reject(err);
      else {
        console.log('Database initialized');
        resolve();
      }
    });
  });
}

export function query(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => {
      if (err) reject(err);
      else resolve(rows);
    });
  });
}

export function run(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function(err) {
      if (err) reject(err);
      else resolve({ id: this.lastID, changes: this.changes });
    });
  });
}
```

### server/db/schema.sql
```sql
CREATE TABLE IF NOT EXISTS prompts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_path TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  category TEXT,
  model TEXT,
  tags TEXT,
  frontmatter TEXT,
  last_modified INTEGER,
  checksum TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_prompts_category ON prompts(category);
CREATE INDEX IF NOT EXISTS idx_prompts_model ON prompts(model);

CREATE VIRTUAL TABLE IF NOT EXISTS prompt_search USING fts5(
  title, 
  content, 
  tags,
  content=prompts,
  content_rowid=id
);

CREATE TRIGGER IF NOT EXISTS prompts_ai AFTER INSERT ON prompts BEGIN
  INSERT INTO prompt_search(rowid, title, content, tags) 
  VALUES (new.id, new.title, new.content, new.tags);
END;

CREATE TRIGGER IF NOT EXISTS prompts_ad AFTER DELETE ON prompts BEGIN
  DELETE FROM prompt_search WHERE rowid = old.id;
END;

CREATE TRIGGER IF NOT EXISTS prompts_au AFTER UPDATE ON prompts BEGIN
  DELETE FROM prompt_search WHERE rowid = old.id;
  INSERT INTO prompt_search(rowid, title, content, tags) 
  VALUES (new.id, new.title, new.content, new.tags);
END;
```

### server/services/fileService.js
```javascript
import fs from 'fs/promises';
import path from 'path';
import matter from 'gray-matter';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROMPTS_DIR = path.join(__dirname, '../../../prompts');

export async function ensurePromptsDirectory() {
  try {
    await fs.access(PROMPTS_DIR);
  } catch {
    await fs.mkdir(PROMPTS_DIR, { recursive: true });
  }
}

export async function readPromptFile(filePath) {
  const content = await fs.readFile(filePath, 'utf-8');
  const { data, content: promptContent } = matter(content);
  
  return {
    frontmatter: data,
    content: promptContent,
    checksum: crypto.createHash('md5').update(content).digest('hex')
  };
}

export async function writePromptFile(category, filename, frontmatter, content) {
  await ensurePromptsDirectory();
  
  const categoryDir = path.join(PROMPTS_DIR, category);
  await fs.mkdir(categoryDir, { recursive: true });
  
  const filePath = path.join(categoryDir, filename);
  const fileContent = matter.stringify(content, frontmatter);
  
  await fs.writeFile(filePath, fileContent, 'utf-8');
  
  return path.relative(PROMPTS_DIR, filePath);
}

export async function deletePromptFile(filePath) {
  const fullPath = path.join(PROMPTS_DIR, filePath);
  await fs.unlink(fullPath);
}

export async function getAllPromptFiles() {
  await ensurePromptsDirectory();
  
  const files = [];
  
  async function scanDirectory(dir) {
    const entries = await fs.readdir(dir, { withFileTypes: true });
    
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      
      if (entry.isDirectory()) {
        await scanDirectory(fullPath);
      } else if (entry.name.endsWith('.md')) {
        files.push(fullPath);
      }
    }
  }
  
  await scanDirectory(PROMPTS_DIR);
  return files;
}
```

### server/services/indexService.js
```javascript
import path from 'path';
import { fileURLToPath } from 'url';
import { readPromptFile, getAllPromptFiles } from './fileService.js';
import { query, run } from '../db/database.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROMPTS_DIR = path.join(__dirname, '../../../prompts');

export async function indexPromptFile(filePath) {
  try {
    const { frontmatter, content, checksum } = await readPromptFile(filePath);
    const relativePath = path.relative(PROMPTS_DIR, filePath);
    const category = path.dirname(relativePath);
    
    const existing = await query('SELECT id, checksum FROM prompts WHERE file_path = ?', [relativePath]);
    
    if (existing.length > 0 && existing[0].checksum === checksum) {
      return; // No changes
    }
    
    const promptData = {
      file_path: relativePath,
      title: frontmatter.title || path.basename(filePath, '.md'),
      content: content,
      category: category === '.' ? 'uncategorized' : category,
      model: frontmatter.model || null,
      tags: Array.isArray(frontmatter.tags) ? frontmatter.tags.join(', ') : '',
      frontmatter: JSON.stringify(frontmatter),
      last_modified: Date.now(),
      checksum: checksum
    };
    
    if (existing.length > 0) {
      // Update existing
      await run(
        `UPDATE prompts SET 
          title = ?, content = ?, category = ?, model = ?, 
          tags = ?, frontmatter = ?, last_modified = ?, checksum = ?,
          updated_at = CURRENT_TIMESTAMP
        WHERE file_path = ?`,
        [
          promptData.title, promptData.content, promptData.category,
          promptData.model, promptData.tags, promptData.frontmatter,
          promptData.last_modified, promptData.checksum, promptData.file_path
        ]
      );
    } else {
      // Insert new
      await run(
        `INSERT INTO prompts 
          (file_path, title, content, category, model, tags, frontmatter, last_modified, checksum)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          promptData.file_path, promptData.title, promptData.content,
          promptData.category, promptData.model, promptData.tags,
          promptData.frontmatter, promptData.last_modified, promptData.checksum
        ]
      );
    }
    
    console.log(`Indexed: ${relativePath}`);
  } catch (error) {
    console.error(`Error indexing ${filePath}:`, error);
  }
}

export async function removeFromIndex(filePath) {
  const relativePath = path.relative(PROMPTS_DIR, filePath);
  await run('DELETE FROM prompts WHERE file_path = ?', [relativePath]);
  console.log(`Removed from index: ${relativePath}`);
}

export async function reindexAll() {
  console.log('Starting full reindex...');
  
  // Get all files from filesystem
  const files = await getAllPromptFiles();
  const filePaths = files.map(f => path.relative(PROMPTS_DIR, f));
  
  // Get all files from database
  const dbFiles = await query('SELECT file_path FROM prompts');
  const dbFilePaths = dbFiles.map(f => f.file_path);
  
  // Remove deleted files from index
  for (const dbPath of dbFilePaths) {
    if (!filePaths.includes(dbPath)) {
      await run('DELETE FROM prompts WHERE file_path = ?', [dbPath]);
      console.log(`Removed deleted file: ${dbPath}`);
    }
  }
  
  // Index all current files
  for (const file of files) {
    await indexPromptFile(file);
  }
  
  console.log('Reindexing complete');
}
```

### server/services/watchService.js
```javascript
import chokidar from 'chokidar';
import path from 'path';
import { fileURLToPath } from 'url';
import { indexPromptFile, removeFromIndex } from './indexService.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROMPTS_DIR = path.join(__dirname, '../../../prompts');

export function watchPromptFiles() {
  const watcher = chokidar.watch(PROMPTS_DIR, {
    ignored: /(^|[\/\\])\../, // ignore dotfiles
    persistent: true,
    ignoreInitial: true
  });
  
  watcher
    .on('add', path => {
      if (path.endsWith('.md')) {
        console.log(`File added: ${path}`);
        indexPromptFile(path);
      }
    })
    .on('change', path => {
      if (path.endsWith('.md')) {
        console.log(`File changed: ${path}`);
        indexPromptFile(path);
      }
    })
    .on('unlink', path => {
      if (path.endsWith('.md')) {
        console.log(`File removed: ${path}`);
        removeFromIndex(path);
      }
    });
  
  console.log('Watching for prompt file changes...');
}
```

### server/routes/prompts.js
```javascript
import express from 'express';
import { query, run } from '../db/database.js';
import { writePromptFile, deletePromptFile } from '../services/fileService.js';
import { indexPromptFile } from '../services/indexService.js';

const router = express.Router();

// Get all prompts
router.get('/', async (req, res) => {
  try {
    const { search, category, model } = req.query;
    let sql = 'SELECT * FROM prompts WHERE 1=1';
    const params = [];
    
    if (search) {
      sql = `
        SELECT p.* FROM prompts p
        JOIN prompt_search ps ON p.id = ps.rowid
        WHERE prompt_search MATCH ?
      `;
      params.push(search);
      
      if (category) {
        sql += ' AND p.category = ?';
        params.push(category);
      }
      if (model) {
        sql += ' AND p.model = ?';
        params.push(model);
      }
    } else {
      if (category) {
        sql += ' AND category = ?';
        params.push(category);
      }
      if (model) {
        sql += ' AND model = ?';
        params.push(model);
      }
    }
    
    sql += ' ORDER BY updated_at DESC';
    
    const prompts = await query(sql, params);
    res.json(prompts);
  } catch (error) {
    console.error('Error fetching prompts:', error);
    res.status(500).json({ error: 'Failed to fetch prompts' });
  }
});

// Get single prompt
router.get('/:id', async (req, res) => {
  try {
    const prompt = await query('SELECT * FROM prompts WHERE id = ?', [req.params.id]);
    if (prompt.length === 0) {
      return res.status(404).json({ error: 'Prompt not found' });
    }
    res.json(prompt[0]);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch prompt' });
  }
});

// Create new prompt
router.post('/', async (req, res) => {
  try {
    const { title, content, category = 'uncategorized', model, tags = [] } = req.body;
    
    if (!title || !content) {
      return res.status(400).json({ error: 'Title and content are required' });
    }
    
    const filename = `${title.toLowerCase().replace(/[^a-z0-9]+/g, '-')}.md`;
    const frontmatter = {
      title,
      model,
      tags,
      created: new Date().toISOString().split('T')[0],
      version: '1.0'
    };
    
    const filePath = await writePromptFile(category, filename, frontmatter, content);
    
    // The file watcher will automatically index it, but we'll do it immediately
    const fullPath = path.join(__dirname, '../../../prompts', filePath);
    await indexPromptFile(fullPath);
    
    res.json({ success: true, filePath });
  } catch (error) {
    console.error('Error creating prompt:', error);
    res.status(500).json({ error: 'Failed to create prompt' });
  }
});

// Update prompt
router.put('/:id', async (req, res) => {
  try {
    const { title, content, category, model, tags } = req.body;
    
    // Get existing prompt
    const existing = await query('SELECT * FROM prompts WHERE id = ?', [req.params.id]);
    if (existing.length === 0) {
      return res.status(404).json({ error: 'Prompt not found' });
    }
    
    const prompt = existing[0];
    const oldFrontmatter = JSON.parse(prompt.frontmatter);
    
    // Update frontmatter
    const frontmatter = {
      ...oldFrontmatter,
      title: title || oldFrontmatter.title,
      model: model !== undefined ? model : oldFrontmatter.model,
      tags: tags !== undefined ? tags : oldFrontmatter.tags,
      updated: new Date().toISOString().split('T')[0],
      version: String(parseFloat(oldFrontmatter.version || '1.0') + 0.1)
    };
    
    // Delete old file if category changed
    if (category && category !== prompt.category) {
      await deletePromptFile(prompt.file_path);
    }
    
    // Write new file
    const filename = path.basename(prompt.file_path);
    const filePath = await writePromptFile(
      category || prompt.category,
      filename,
      frontmatter,
      content || prompt.content
    );
    
    res.json({ success: true, filePath });
  } catch (error) {
    console.error('Error updating prompt:', error);
    res.status(500).json({ error: 'Failed to update prompt' });
  }
});

// Delete prompt
router.delete('/:id', async (req, res) => {
  try {
    const prompt = await query('SELECT file_path FROM prompts WHERE id = ?', [req.params.id]);
    if (prompt.length === 0) {
      return res.status(404).json({ error: 'Prompt not found' });
    }
    
    await deletePromptFile(prompt[0].file_path);
    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting prompt:', error);
    res.status(500).json({ error: 'Failed to delete prompt' });
  }
});

// Get categories
router.get('/meta/categories', async (req, res) => {
  try {
    const categories = await query(
      'SELECT DISTINCT category, COUNT(*) as count FROM prompts GROUP BY category'
    );
    res.json(categories);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch categories' });
  }
});

export default router;
```

### server/routes/sync.js
```javascript
import express from 'express';
import { reindexAll } from '../services/indexService.js';

const router = express.Router();

// Trigger full reindex
router.post('/reindex', async (req, res) => {
  try {
    await reindexAll();
    res.json({ success: true, message: 'Reindexing complete' });
  } catch (error) {
    console.error('Error reindexing:', error);
    res.status(500).json({ error: 'Failed to reindex' });
  }
});

export default router;
```

## Frontend Implementation

### client/package.json
```json
{
  "name": "promptforge-client",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "axios": "^1.6.0",
    "@monaco-editor/react": "^4.6.0",
    "react-markdown": "^9.0.0"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "devDependencies": {
    "react-scripts": "5.0.1"
  },
  "proxy": "http://localhost:3001"
}
```

### client/src/App.js
```javascript
import React, { useState, useEffect } from 'react';
import PromptList from './components/PromptList';
import PromptEditor from './components/PromptEditor';
import SearchBar from './components/SearchBar';
import { getPrompts, getCategories } from './api/prompts';
import './App.css';

function App() {
  const [prompts, setPrompts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [selectedPrompt, setSelectedPrompt] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('');
  const [isCreating, setIsCreating] = useState(false);

  useEffect(() => {
    loadPrompts();
    loadCategories();
  }, [searchQuery, selectedCategory]);

  const loadPrompts = async () => {
    const data = await getPrompts({ search: searchQuery, category: selectedCategory });
    setPrompts(data);
  };

  const loadCategories = async () => {
    const data = await getCategories();
    setCategories(data);
  };

  const handlePromptSelect = (prompt) => {
    setSelectedPrompt(prompt);
    setIsCreating(false);
  };

  const handleCreateNew = () => {
    setSelectedPrompt(null);
    setIsCreating(true);
  };

  const handleSave = () => {
    loadPrompts();
    loadCategories();
    setIsCreating(false);
  };

  const handleDelete = () => {
    loadPrompts();
    setSelectedPrompt(null);
  };

  return (
    <div className="app">
      <header className="app-header">
        <h1>PromptForge</h1>
        <p>Manage your LLM prompts with version control</p>
      </header>
      
      <div className="app-content">
        <aside className="sidebar">
          <SearchBar 
            onSearch={setSearchQuery}
            categories={categories}
            selectedCategory={selectedCategory}
            onCategoryChange={setSelectedCategory}
          />
          <button className="create-button" onClick={handleCreateNew}>
            + New Prompt
          </button>
          <PromptList 
            prompts={prompts}
            selectedPrompt={selectedPrompt}
            onSelect={handlePromptSelect}
          />
        </aside>
        
        <main className="main-content">
          {(selectedPrompt || isCreating) && (
            <PromptEditor
              prompt={selectedPrompt}
              onSave={handleSave}
              onDelete={handleDelete}
            />
          )}
          {!selectedPrompt && !isCreating && (
            <div className="empty-state">
              <h2>Select a prompt or create a new one</h2>
              <p>Your prompts are stored as markdown files in the repository</p>
            </div>
          )}
        </main>
      </div>
    </div>
  );
}

export default App;
```

### client/src/components/PromptEditor.js
```javascript
import React, { useState, useEffect } from 'react';
import Editor from '@monaco-editor/react';
import ReactMarkdown from 'react-markdown';
import { createPrompt, updatePrompt, deletePrompt } from '../api/prompts';

function PromptEditor({ prompt, onSave, onDelete }) {
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [category, setCategory] = useState('uncategorized');
  const [model, setModel] = useState('');
  const [tags, setTags] = useState([]);
  const [isPreview, setIsPreview] = useState(false);

  useEffect(() => {
    if (prompt) {
      setTitle(prompt.title);
      setContent(prompt.content);
      setCategory(prompt.category);
      setModel(prompt.model || '');
      
      const frontmatter = JSON.parse(prompt.frontmatter);
      setTags(frontmatter.tags || []);
    } else {
      // Reset for new prompt
      setTitle('');
      setContent('');
      setCategory('uncategorized');
      setModel('');
      setTags([]);
    }
  }, [prompt]);

  const handleSave = async () => {
    const promptData = {
      title,
      content,
      category,
      model: model || null,
      tags
    };

    try {
      if (prompt) {
        await updatePrompt(prompt.id, promptData);
      } else {
        await createPrompt(promptData);
      }
      onSave();
    } catch (error) {
      console.error('Error saving prompt:', error);
      alert('Failed to save prompt');
    }
  };

  const handleDelete = async () => {
    if (!prompt || !window.confirm('Are you sure you want to delete this prompt?')) {
      return;
    }

    try {
      await deletePrompt(prompt.id);
      onDelete();
    } catch (error) {
      console.error('Error deleting prompt:', error);
      alert('Failed to delete prompt');
    }
  };

  const handleTagInput = (e) => {
    if (e.key === 'Enter' && e.target.value.trim()) {
      e.preventDefault();
      setTags([...tags, e.target.value.trim()]);
      e.target.value = '';
    }
  };

  const removeTag = (index) => {
    setTags(tags.filter((_, i) => i !== index));
  };

  return (
    <div className="prompt-editor">
      <div className="editor-header">
        <input
          type="text"
          placeholder="Prompt Title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          className="title-input"
        />
        <div className="editor-actions">
          <button onClick={() => setIsPreview(!isPreview)}>
            {isPreview ? 'Edit' : 'Preview'}
          </button>
          <button onClick={handleSave} className="save-button">
            Save
          </button>
          {prompt && (
            <button onClick={handleDelete} className="delete-button">
              Delete
            </button>
          )}
        </div>
      </div>

      <div className="editor-metadata">
        <div className="metadata-field">
          <label>Category:</label>
          <input
            type="text"
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            placeholder="e.g., coding, debugging"
          />
        </div>
        <div className="metadata-field">
          <label>Model:</label>
          <input
            type="text"
            value={model}
            onChange={(e) => setModel(e.target.value)}
            placeholder="e.g., claude-3-opus"
          />
        </div>
        <div className="metadata-field">
          <label>Tags:</label>
          <div className="tags-container">
            {tags.map((tag, index) => (
              <span key={index} className="tag">
                {tag}
                <button onClick={() => removeTag(index)}>×</button>
              </span>
            ))}
            <input
              type="text"
              onKeyDown={handleTagInput}
              placeholder="Add tag and press Enter"
              className="tag-input"
            />
          </div>
        </div>
      </div>

      <div className="editor-content">
        {isPreview ? (
          <div className="preview">
            <ReactMarkdown>{content}</ReactMarkdown>
          </div>
        ) : (
          <Editor
            height="100%"
            defaultLanguage="markdown"
            value={content}
            onChange={setContent}
            theme="vs-dark"
            options={{
              minimap: { enabled: false },
              fontSize: 14,
              wordWrap: 'on',
              lineNumbers: 'off'
            }}
          />
        )}
      </div>
    </div>
  );
}

export default PromptEditor;
```

### client/src/components/PromptList.js
```javascript
import React from 'react';

function PromptList({ prompts, selectedPrompt, onSelect }) {
  return (
    <div className="prompt-list">
      {prompts.map((prompt) => (
        <div
          key={prompt.id}
          className={`prompt-item ${selectedPrompt?.id === prompt.id ? 'selected' : ''}`}
          onClick={() => onSelect(prompt)}
        >
          <h3>{prompt.title}</h3>
          <div className="prompt-meta">
            <span className="category">{prompt.category}</span>
            {prompt.model && <span className="model">{prompt.model}</span>}
          </div>
          <p className="prompt-preview">
            {prompt.content.substring(0, 100)}...
          </p>
        </div>
      ))}
    </div>
  );
}

export default PromptList;
```

### client/src/components/SearchBar.js
```javascript
import React, { useState } from 'react';

function SearchBar({ onSearch, categories, selectedCategory, onCategoryChange }) {
  const [searchTerm, setSearchTerm] = useState('');

  const handleSearch = (e) => {
    e.preventDefault();
    onSearch(searchTerm);
  };

  return (
    <div className="search-bar">
      <form onSubmit={handleSearch}>
        <input
          type="text"
          placeholder="Search prompts..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="search-input"
        />
      </form>
      
      <div className="category-filter">
        <label>Category:</label>
        <select 
          value={selectedCategory} 
          onChange={(e) => onCategoryChange(e.target.value)}
        >
          <option value="">All Categories</option>
          {categories.map((cat) => (
            <option key={cat.category} value={cat.category}>
              {cat.category} ({cat.count})
            </option>
          ))}
        </select>
      </div>
    </div>
  );
}

export default SearchBar;
```

### client/src/api/prompts.js
```javascript
import axios from 'axios';

const API_BASE = '/api';

export const getPrompts = async (params = {}) => {
  const response = await axios.get(`${API_BASE}/prompts`, { params });
  return response.data;
};

export const getPrompt = async (id) => {
  const response = await axios.get(`${API_BASE}/prompts/${id}`);
  return response.data;
};

export const createPrompt = async (promptData) => {
  const response = await axios.post(`${API_BASE}/prompts`, promptData);
  return response.data;
};

export const updatePrompt = async (id, promptData) => {
  const response = await axios.put(`${API_BASE}/prompts/${id}`, promptData);
  return response.data;
};

export const deletePrompt = async (id) => {
  const response = await axios.delete(`${API_BASE}/prompts/${id}`);
  return response.data;
};

export const getCategories = async () => {
  const response = await axios.get(`${API_BASE}/prompts/meta/categories`);
  return response.data;
};

export const reindexPrompts = async () => {
  const response = await axios.post(`${API_BASE}/sync/reindex`);
  return response.data;
};
```

### client/src/App.css
```css
* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
  background-color: #0d1117;
  color: #c9d1d9;
}

.app {
  height: 100vh;
  display: flex;
  flex-direction: column;
}

.app-header {
  background-color: #161b22;
  padding: 1rem 2rem;
  border-bottom: 1px solid #30363d;
}

.app-header h1 {
  font-size: 1.5rem;
  margin-bottom: 0.25rem;
}

.app-header p {
  color: #8b949e;
  font-size: 0.875rem;
}

.app-content {
  flex: 1;
  display: flex;
  overflow: hidden;
}

.sidebar {
  width: 300px;
  background-color: #0d1117;
  border-right: 1px solid #30363d;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.main-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* Search Bar */
.search-bar {
  padding: 1rem;
  border-bottom: 1px solid #30363d;
}

.search-input {
  width: 100%;
  padding: 0.5rem;
  background-color: #0d1117;
  border: 1px solid #30363d;
  border-radius: 6px;
  color: #c9d1d9;
  margin-bottom: 0.5rem;
}

.category-filter {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.category-filter select {
  flex: 1;
  padding: 0.25rem;
  background-color: #0d1117;
  border: 1px solid #30363d;
  border-radius: 6px;
  color: #c9d1d9;
}

/* Create Button */
.create-button {
  margin: 0 1rem 1rem;
  padding: 0.75rem;
  background-color: #238636;
  color: white;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-weight: 500;
}

.create-button:hover {
  background-color: #2ea043;
}

/* Prompt List */
.prompt-list {
  flex: 1;
  overflow-y: auto;
  padding: 0 1rem 1rem;
}

.prompt-item {
  padding: 1rem;
  margin-bottom: 0.5rem;
  background-color: #161b22;
  border: 1px solid #30363d;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s;
}

.prompt-item:hover {
  border-color: #58a6ff;
}

.prompt-item.selected {
  border-color: #58a6ff;
  background-color: #1f2937;
}

.prompt-item h3 {
  font-size: 1rem;
  margin-bottom: 0.5rem;
}

.prompt-meta {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.prompt-meta span {
  font-size: 0.75rem;
  padding: 0.125rem 0.5rem;
  border-radius: 12px;
  background-color: #30363d;
}

.prompt-preview {
  font-size: 0.875rem;
  color: #8b949e;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Prompt Editor */
.prompt-editor {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.editor-header {
  display: flex;
  align-items: center;
  padding: 1rem;
  border-bottom: 1px solid #30363d;
  gap: 1rem;
}

.title-input {
  flex: 1;
  font-size: 1.25rem;
  padding: 0.5rem;
  background-color: transparent;
  border: 1px solid transparent;
  color: #c9d1d9;
  border-radius: 6px;
}

.title-input:focus {
  outline: none;
  border-color: #30363d;
  background-color: #0d1117;
}

.editor-actions {
  display: flex;
  gap: 0.5rem;
}

.editor-actions button {
  padding: 0.5rem 1rem;
  border: 1px solid #30363d;
  background-color: #21262d;
  color: #c9d1d9;
  border-radius: 6px;
  cursor: pointer;
}

.save-button {
  background-color: #238636 !important;
  border-color: #238636 !important;
  color: white !important;
}

.delete-button {
  background-color: #da3633 !important;
  border-color: #da3633 !important;
  color: white !important;
}

/* Editor Metadata */
.editor-metadata {
  padding: 1rem;
  border-bottom: 1px solid #30363d;
  display: flex;
  gap: 1rem;
}

.metadata-field {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.metadata-field label {
  font-size: 0.875rem;
  color: #8b949e;
}

.metadata-field input {
  padding: 0.25rem 0.5rem;
  background-color: #0d1117;
  border: 1px solid #30363d;
  border-radius: 6px;
  color: #c9d1d9;
}

/* Tags */
.tags-container {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.tag {
  display: inline-flex;
  align-items: center;
  padding: 0.25rem 0.5rem;
  background-color: #1f6feb;
  color: white;
  border-radius: 12px;
  font-size: 0.75rem;
}

.tag button {
  margin-left: 0.25rem;
  background: none;
  border: none;
  color: white;
  cursor: pointer;
  font-size: 1rem;
  line-height: 1;
}

.tag-input {
  padding: 0.25rem 0.5rem;
  background-color: #0d1117;
  border: 1px solid #30363d;
  border-radius: 6px;
  color: #c9d1d9;
  font-size: 0.875rem;
}

/* Editor Content */
.editor-content {
  flex: 1;
  overflow: hidden;
}

.preview {
  height: 100%;
  padding: 2rem;
  overflow-y: auto;
}

.preview h1, .preview h2, .preview h3 {
  margin-top: 1.5rem;
  margin-bottom: 1rem;
}

.preview p {
  margin-bottom: 1rem;
  line-height: 1.6;
}

.preview code {
  background-color: #161b22;
  padding: 0.125rem 0.25rem;
  border-radius: 3px;
}

.preview pre {
  background-color: #161b22;
  padding: 1rem;
  border-radius: 6px;
  overflow-x: auto;
  margin-bottom: 1rem;
}

/* Empty State */
.empty-state {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 2rem;
}

.empty-state h2 {
  margin-bottom: 1rem;
}

.empty-state p {
  color: #8b949e;
}
```

## Root Configuration Files

### .gitignore
```
# Dependencies
node_modules/
.pnp
.pnp.js

# Testing
coverage/

# Production
build/
dist/

# Database
*.db
*.db-journal
promptforge.db

# Misc
.DS_Store
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
npm-debug.log*
yarn-debug.log*
yarn-error.log*
lerna-debug.log*

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
Thumbs.db
```

### package.json (root)
```json
{
  "name": "promptforge",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "install:all": "npm install && cd server && npm install && cd ../client && npm install",
    "dev": "concurrently \"npm run dev:server\" \"npm run dev:client\"",
    "dev:server": "cd server && npm run dev",
    "dev:client": "cd client && npm start",
    "build": "cd client && npm run build",
    "start": "cd server && npm start",
    "init-db": "cd server && npm run init-db"
  },
  "devDependencies": {
    "concurrently": "^8.2.0"
  }
}
```

### README.md
```markdown
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
   git clone https://github.com/yourusername/promptforge.git
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

## Sample Issues for Testing

After forking, run `./setup-issues.sh` to create sample issues for testing with your LLM automation tools.
```

### prompts/README.md
```markdown
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
```

## Setup and Usage

1. **Initial Setup:**
   ```bash
   cd promptforge
   npm run install:all
   npm run init-db
   ```

2. **Development:**
   ```bash
   npm run dev
   ```

3. **Creating Prompts:**
   - Use the web interface to create/edit prompts
   - Files are saved to the `/prompts` directory
   - SQLite database provides fast searching

4. **Version Control:**
   - The `.gitignore` excludes the SQLite database
   - All markdown files in `/prompts` are tracked
   - Push changes to share prompts with your team

5. **Reindexing:**
   - Happens automatically when files change
   - Can manually trigger via the API: `POST /api/sync/reindex`

