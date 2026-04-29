local M = {}

local config = require("vimseq.config")
local db = require("vimseq.db")
local sync = require("vimseq.db.sync")

--- Create a new note with the given title
---@param title string
---@return string abs_path The absolute path to the created note
function M.create(title)
  local cfg = config.get()
  local rel_path = sync.title_to_path(title)
  local abs_path = sync.abs_path(rel_path)

  -- Check if file already exists
  if vim.loop.fs_stat(abs_path) then
    return abs_path -- already exists, just return it
  end

  -- Ensure parent directory exists
  local parent = abs_path:match("(.+)/[^/]+$")
  if parent then
    vim.fn.mkdir(parent, "p")
  end

  -- Generate content from template
  local content = cfg.template_fn(title)

  -- Write file
  local fd = vim.loop.fs_open(abs_path, "w", 438)
  if fd then
    vim.loop.fs_write(fd, content, 0)
    vim.loop.fs_close(fd)
  end

  -- Index the new file
  sync.sync_file(abs_path, true)

  -- Resolve links that may now point to this new note
  db.resolve_links()

  return abs_path
end

--- Open a note in the current window
---@param abs_path string
function M.open(abs_path)
  vim.cmd("edit " .. vim.fn.fnameescape(abs_path))
end

--- Get the title of the current buffer's note
---@return string|nil
function M.current_title()
  local buf_path = vim.api.nvim_buf_get_name(0)
  if not buf_path or buf_path == "" then
    return nil
  end

  local cfg = config.get()
  -- Check if this file is inside the vault
  if buf_path:sub(1, #cfg.vault_path) ~= cfg.vault_path then
    return nil
  end

  local rel_path = buf_path:sub(#cfg.vault_path + 2)
  local note = db.get_note_by_path(rel_path)
  if note then
    return note.title
  end
  return nil
end

--- Check if the current buffer is inside the vault
---@return boolean
function M.is_in_vault()
  local buf_path = vim.api.nvim_buf_get_name(0)
  if not buf_path or buf_path == "" then
    return false
  end
  local cfg = config.get()
  return buf_path:sub(1, #cfg.vault_path) == cfg.vault_path
end

--- Get the current buffer's note record from the DB
---@return table|nil
function M.current_note()
  local buf_path = vim.api.nvim_buf_get_name(0)
  if not buf_path or buf_path == "" then
    return nil
  end
  local cfg = config.get()
  if buf_path:sub(1, #cfg.vault_path) ~= cfg.vault_path then
    return nil
  end
  local rel_path = buf_path:sub(#cfg.vault_path + 2)
  return db.get_note_by_path(rel_path)
end

return M
