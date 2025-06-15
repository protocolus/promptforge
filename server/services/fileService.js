import fs from 'fs/promises';
import path from 'path';
import matter from 'gray-matter';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROMPTS_DIR = path.join(__dirname, '../../prompts');

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