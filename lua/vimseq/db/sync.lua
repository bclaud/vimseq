local M = {}

local config = require("vimseq.config")
local db = require("vimseq.db")
local parser = require("vimseq.parser")

--- Compute a simple hash of file content for change detection
---@param content string
---@return string
local function hash_content(content)
  -- Use a simple djb2 hash implemented in Lua (fast enough for our purposes)
  local hash = 5381
  for i = 1, #content do
    hash = ((hash * 33) + content:byte(i)) % 2147483647
  end
  return tostring(hash)
end

--- Recursively scan a directory for .md files
---@param dir string Absolute directory path
---@return string[] List of absolute file paths
local function scan_directory(dir)
  local files = {}
  local handle = vim.loop.fs_scandir(dir)
  if not handle then
    return files
  end

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end

    local full_path = dir .. "/" .. name

    if type == "file" and name:match("%.md$") then
      table.insert(files, full_path)
    elseif type == "directory" and not name:match("^%.") then
      -- Recurse into subdirectories (skip hidden dirs like .git)
      local sub_files = scan_directory(full_path)
      for _, f in ipairs(sub_files) do
        table.insert(files, f)
      end
    end
  end

  return files
end

--- Get the relative path from vault root
---@param abs_path string
---@return string
local function relative_path(abs_path)
  local vault = config.get().vault_path
  if abs_path:sub(1, #vault) == vault then
    local rel = abs_path:sub(#vault + 2) -- +2 to skip the /
    return rel
  end
  return abs_path
end

--- Get filename without extension from a path
---@param path string
---@return string
local function filename_stem(path)
  local name = path:match("([^/]+)$") or path
  return name:gsub("%.md$", "")
end

--- Sync a single file into the database
---@param abs_path string Absolute path to the .md file
---@param force boolean|nil Force re-index even if hash matches
function M.sync_file(abs_path, force)
  local rel_path = relative_path(abs_path)

  -- Read file content
  local fd = vim.loop.fs_open(abs_path, "r", 438) -- 0666
  if not fd then
    return
  end
  local stat = vim.loop.fs_fstat(fd)
  if not stat then
    vim.loop.fs_close(fd)
    return
  end
  local content = vim.loop.fs_read(fd, stat.size, 0)
  vim.loop.fs_close(fd)

  if not content then
    return
  end

  -- Check if content has changed
  local new_hash = hash_content(content)
  if not force then
    local old_hash = db.get_content_hash(rel_path)
    if old_hash == new_hash then
      return -- no changes
    end
  end

  -- Parse the note
  local stem = filename_stem(rel_path)
  local parsed = parser.parse_note(content, stem)

  -- Upsert the note record
  local note_id = db.upsert_note(rel_path, parsed.title, new_hash)

  -- Clear and re-insert links
  db.clear_links(note_id)
  for _, link in ipairs(parsed.links) do
    db.insert_link(note_id, link.target, link.line_number, link.display)
  end

  -- Clear and re-insert tags
  db.clear_tags(note_id)
  for _, tag in ipairs(parsed.tags) do
    db.insert_tag(note_id, tag)
  end

  -- Also insert frontmatter tags
  -- (already merged in parser.parse_note, so parsed.tags has both)
end

--- Full sync: scan the entire vault and index all files
function M.full_sync()
  local cfg = config.get()
  local files = scan_directory(cfg.vault_path)

  -- Track which paths we've seen (to detect deleted files)
  local seen_paths = {}

  for _, abs_path in ipairs(files) do
    M.sync_file(abs_path)
    local rel = relative_path(abs_path)
    seen_paths[rel] = true
  end

  -- Remove notes from DB that no longer exist on disk
  local all_notes = db.get_all_notes()
  for _, note in ipairs(all_notes) do
    if not seen_paths[note.path] then
      db.delete_note(note.id)
    end
  end

  -- Resolve all link target_ids after full sync
  db.resolve_links()
end

--- Get absolute path for a relative vault path
---@param rel_path string
---@return string
function M.abs_path(rel_path)
  return config.get().vault_path .. "/" .. rel_path
end

--- Get relative path for a note title (constructs the expected path)
---@param title string
---@return string
function M.title_to_path(title)
  local cfg = config.get()
  local name = cfg.note_name_fn(title)
  return name .. ".md"
end

return M
