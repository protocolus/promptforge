import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import { query, run } from '../db/database.js';
import { writePromptFile, deletePromptFile } from '../services/fileService.js';
import { indexPromptFile } from '../services/indexService.js';

const router = express.Router();
const __dirname = path.dirname(fileURLToPath(import.meta.url));

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
    const fullPath = path.join(__dirname, '../../prompts', filePath);
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