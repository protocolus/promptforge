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

// If this file is run directly, initialize the database
if (import.meta.url === `file://${process.argv[1]}`) {
  initDatabase().then(() => {
    console.log('Database setup complete');
    process.exit(0);
  }).catch(error => {
    console.error('Database setup failed:', error);
    process.exit(1);
  });
}