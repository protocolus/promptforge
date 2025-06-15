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