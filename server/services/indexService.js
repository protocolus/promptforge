import path from 'path';
import { fileURLToPath } from 'url';
import { readPromptFile, getAllPromptFiles } from './fileService.js';
import { query, run } from '../db/database.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROMPTS_DIR = path.join(__dirname, '../../prompts');

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