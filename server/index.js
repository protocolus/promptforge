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

// API Routes
app.use('/api/prompts', promptRoutes);
app.use('/api/sync', syncRoutes);

// Serve static files from React build
const clientBuildPath = path.join(__dirname, '..', 'client', 'build');
app.use(express.static(clientBuildPath));

// Catch all handler - send React app for any route not handled by API
app.get('*', (req, res) => {
  res.sendFile(path.join(clientBuildPath, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`PromptForge server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});