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