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
const unusedVar = 'test';

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
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});