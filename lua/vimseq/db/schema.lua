local M = {}

--- SQL statements for creating the VimSeq database schema.
--- Each statement must be separate because sqlite.lua's eval() only
--- executes one statement per call.
M.create_tables = {
  [[
    CREATE TABLE IF NOT EXISTS notes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      path TEXT UNIQUE NOT NULL,
      title TEXT NOT NULL,
      content_hash TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      modified_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ]],
  [[
    CREATE TABLE IF NOT EXISTS links (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      source_id INTEGER NOT NULL,
      target_title TEXT NOT NULL,
      target_id INTEGER,
      line_number INTEGER NOT NULL DEFAULT 0,
      display_text TEXT,
      FOREIGN KEY (source_id) REFERENCES notes(id) ON DELETE CASCADE,
      FOREIGN KEY (target_id) REFERENCES notes(id) ON DELETE SET NULL
    )
  ]],
  [[
    CREATE TABLE IF NOT EXISTS tags (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      note_id INTEGER NOT NULL,
      tag TEXT NOT NULL,
      FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
    )
  ]],
  "CREATE INDEX IF NOT EXISTS idx_notes_path ON notes(path)",
  "CREATE INDEX IF NOT EXISTS idx_notes_title ON notes(title)",
  "CREATE INDEX IF NOT EXISTS idx_links_source ON links(source_id)",
  "CREATE INDEX IF NOT EXISTS idx_links_target_title ON links(target_title)",
  "CREATE INDEX IF NOT EXISTS idx_links_target_id ON links(target_id)",
  "CREATE INDEX IF NOT EXISTS idx_tags_note ON tags(note_id)",
  "CREATE INDEX IF NOT EXISTS idx_tags_tag ON tags(tag)",
}

--- SQL for the FTS5 virtual table (Phase 3: full-text search)
M.create_fts = [[
  CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
    title,
    content,
    content_id=notes,
    content_rowid=id
  );
]]

return M
