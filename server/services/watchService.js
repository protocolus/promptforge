import chokidar from 'chokidar';
import path from 'path';
import { fileURLToPath } from 'url';
import { indexPromptFile, removeFromIndex } from './indexService.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROMPTS_DIR = path.join(__dirname, '../../prompts');

export function watchPromptFiles() {
  const watcher = chokidar.watch(PROMPTS_DIR, {
    ignored: /(^|[/\\])\../, // ignore dotfiles
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