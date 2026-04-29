local M = {}

---@type table|nil The sqlite.lua database handle
M._db = nil

--- Normalize sqlite.lua eval() results.
--- eval() returns true for successful queries with no rows, or a table of rows.
--- This ensures we always get a table.
---@param result any
---@return table[]
local function normalize(result)
  if type(result) == "table" then
    return result
  end
  return {}
end

--- Initialize the database connection and create schema
---@param db_path string Path to the SQLite database file
function M.setup(db_path)
  local ok, sqlite = pcall(require, "sqlite.db")
  if not ok then
    error("VimSeq requires sqlite.lua (kkharji/sqlite.lua). Install it as a plugin dependency.")
  end

  M._db = sqlite:open(db_path)
  if not M._db then
    error("VimSeq: failed to open database at " .. db_path)
  end

  -- Enable WAL mode for better concurrent read performance
  M._db:eval("PRAGMA journal_mode=WAL")
  M._db:eval("PRAGMA foreign_keys=ON")

  -- Create tables
  local schema = require("vimseq.db.schema")
  M._db:eval(schema.create_tables)
end

--- Get the database handle (errors if not initialized)
---@return table
function M.get()
  if not M._db then
    error("VimSeq: database not initialized. Call require('vimseq').setup() first.")
  end
  return M._db
end

--- Close the database connection
function M.close()
  if M._db then
    M._db:close()
    M._db = nil
  end
end

-- ============================================================
-- Note CRUD operations
-- ============================================================

--- Insert or update a note record
---@param path string Relative file path within vault
---@param title string Note title
---@param content_hash string MD5/hash of file content
---@return integer note_id
function M.upsert_note(path, title, content_hash)
  local db = M.get()

  -- Check if note already exists
  local existing = normalize(db:eval("SELECT id FROM notes WHERE path = ?", { path }))
  if #existing > 0 then
    db:eval(
      "UPDATE notes SET title = ?, content_hash = ?, modified_at = datetime('now') WHERE path = ?",
      { title, content_hash, path }
    )
    return existing[1].id
  else
    db:eval(
      "INSERT INTO notes (path, title, content_hash) VALUES (?, ?, ?)",
      { path, title, content_hash }
    )
    local result = normalize(db:eval("SELECT last_insert_rowid() as id"))
    return result[1].id
  end
end

--- Get a note by its path
---@param path string
---@return table|nil
function M.get_note_by_path(path)
  local db = M.get()
  local result = normalize(db:eval("SELECT * FROM notes WHERE path = ?", { path }))
  if #result > 0 then
    return result[1]
  end
  return nil
end

--- Get a note by its title (case-insensitive)
---@param title string
---@return table|nil
function M.get_note_by_title(title)
  local db = M.get()
  local result = normalize(db:eval("SELECT * FROM notes WHERE LOWER(title) = LOWER(?)", { title }))
  if #result > 0 then
    return result[1]
  end
  return nil
end

--- Get all notes
---@return table[]
function M.get_all_notes()
  local db = M.get()
  return normalize(db:eval("SELECT * FROM notes ORDER BY modified_at DESC"))
end

--- Delete a note and its associated links/tags (cascading)
---@param note_id integer
function M.delete_note(note_id)
  local db = M.get()
  db:eval("DELETE FROM links WHERE source_id = ?", { note_id })
  db:eval("DELETE FROM links WHERE target_id = ?", { note_id })
  db:eval("DELETE FROM tags WHERE note_id = ?", { note_id })
  db:eval("DELETE FROM notes WHERE id = ?", { note_id })
end

-- ============================================================
-- Link operations
-- ============================================================

--- Clear all links from a given source note
---@param source_id integer
function M.clear_links(source_id)
  local db = M.get()
  db:eval("DELETE FROM links WHERE source_id = ?", { source_id })
end

--- Insert a link record
---@param source_id integer The note that contains the link
---@param target_title string The [[target]] title text
---@param line_number integer Line where the link appears
---@param display_text string|nil Alias text if using [[target|display]]
function M.insert_link(source_id, target_title, line_number, display_text)
  local db = M.get()

  -- Try to resolve target_id
  local target = M.get_note_by_title(target_title)
  local target_id = target and target.id or nil

  db:eval(
    "INSERT INTO links (source_id, target_title, target_id, line_number, display_text) VALUES (?, ?, ?, ?, ?)",
    { source_id, target_title, target_id, line_number, display_text }
  )
end

--- Get all backlinks for a given note (notes that link TO this note)
---@param title string The note title to find backlinks for
---@return table[] List of {source_path, source_title, line_number, display_text}
function M.get_backlinks(title)
  local db = M.get()
  return normalize(db:eval([[
    SELECT n.path as source_path, n.title as source_title,
           l.line_number, l.display_text
    FROM links l
    JOIN notes n ON l.source_id = n.id
    WHERE LOWER(l.target_title) = LOWER(?)
    ORDER BY n.modified_at DESC
  ]], { title }))
end

--- Get all forward links from a given note
---@param note_id integer
---@return table[]
function M.get_forward_links(note_id)
  local db = M.get()
  return normalize(db:eval([[
    SELECT l.target_title, l.line_number, l.display_text,
           n.path as target_path
    FROM links l
    LEFT JOIN notes n ON l.target_id = n.id
    WHERE l.source_id = ?
    ORDER BY l.line_number
  ]], { note_id }))
end

--- Get all dangling links (links whose target doesn't exist)
---@return table[]
function M.get_dangling_links()
  local db = M.get()
  return normalize(db:eval([[
    SELECT l.target_title, n.path as source_path, n.title as source_title, l.line_number
    FROM links l
    JOIN notes n ON l.source_id = n.id
    WHERE l.target_id IS NULL
    ORDER BY l.target_title
  ]]))
end

--- Re-resolve all target_id references (e.g. after a new note is created)
function M.resolve_links()
  local db = M.get()
  db:eval([[
    UPDATE links SET target_id = (
      SELECT id FROM notes WHERE LOWER(notes.title) = LOWER(links.target_title)
    )
  ]])
end

-- ============================================================
-- Tag operations
-- ============================================================

--- Clear all tags for a note
---@param note_id integer
function M.clear_tags(note_id)
  local db = M.get()
  db:eval("DELETE FROM tags WHERE note_id = ?", { note_id })
end

--- Insert a tag for a note
---@param note_id integer
---@param tag string
function M.insert_tag(note_id, tag)
  local db = M.get()
  db:eval("INSERT INTO tags (note_id, tag) VALUES (?, ?)", { note_id, tag })
end

--- Get all unique tags
---@return table[]
function M.get_all_tags()
  local db = M.get()
  return normalize(db:eval([[
    SELECT tag, COUNT(*) as count
    FROM tags
    GROUP BY tag
    ORDER BY count DESC, tag ASC
  ]]))
end

--- Get all notes with a specific tag
---@param tag string
---@return table[]
function M.get_notes_by_tag(tag)
  local db = M.get()
  return normalize(db:eval([[
    SELECT n.* FROM notes n
    JOIN tags t ON t.note_id = n.id
    WHERE t.tag = ?
    ORDER BY n.modified_at DESC
  ]], { tag }))
end

--- Get the content hash for a note path
---@param path string
---@return string|nil
function M.get_content_hash(path)
  local db = M.get()
  local result = normalize(db:eval("SELECT content_hash FROM notes WHERE path = ?", { path }))
  if #result > 0 then
    return result[1].content_hash
  end
  return nil
end

--- Rename a note title and update all links referencing the old title
---@param old_title string
---@param new_title string
---@param new_path string
function M.rename_note(old_title, new_title, new_path)
  local db = M.get()
  db:eval("UPDATE notes SET title = ?, path = ?, modified_at = datetime('now') WHERE LOWER(title) = LOWER(?)",
    { new_title, new_path, old_title })
  db:eval("UPDATE links SET target_title = ? WHERE LOWER(target_title) = LOWER(?)",
    { new_title, old_title })
  M.resolve_links()
end

return M
