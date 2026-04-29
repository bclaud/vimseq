local M = {}

local config = require("vimseq.config")
local sync = require("vimseq.db.sync")
local note = require("vimseq.note")
local db = require("vimseq.db")

--- Get the absolute path for a journal entry by date string
---@param date_str string e.g. "2026-04-29"
---@return string abs_path
---@return string rel_path
local function journal_path(date_str)
  local cfg = config.get()
  local rel = cfg.journal_dir .. "/" .. date_str .. ".md"
  local abs = cfg.vault_path .. "/" .. rel
  return abs, rel
end

--- Open (or create) the journal for a given date
---@param date_str string e.g. "2026-04-29"
function M.open_date(date_str)
  local cfg = config.get()
  local abs_path, rel_path = journal_path(date_str)

  if not vim.loop.fs_stat(abs_path) then
    -- Create journal entry
    local parent = abs_path:match("(.+)/[^/]+$")
    if parent then
      vim.fn.mkdir(parent, "p")
    end

    local content = cfg.journal_template_fn(date_str)
    local fd = vim.loop.fs_open(abs_path, "w", 438)
    if fd then
      vim.loop.fs_write(fd, content, 0)
      vim.loop.fs_close(fd)
    end

    -- Index it
    sync.sync_file(abs_path, true)
    db.resolve_links()
  end

  note.open(abs_path)
end

--- Open today's journal
function M.today()
  M.open_date(os.date("%Y-%m-%d"))
end

--- Open yesterday's journal
function M.yesterday()
  local time = os.time() - 86400
  M.open_date(os.date("%Y-%m-%d", time))
end

--- Open tomorrow's journal
function M.tomorrow()
  local time = os.time() + 86400
  M.open_date(os.date("%Y-%m-%d", time))
end

--- Navigate to the previous journal entry (before the current one)
function M.prev()
  local current_date = M._current_journal_date()
  if not current_date then
    vim.notify("VimSeq: current buffer is not a journal entry", vim.log.levels.WARN)
    return
  end

  -- Parse current date and go back one day
  local year, month, day = current_date:match("(%d+)-(%d+)-(%d+)")
  if not year then return end
  local time = os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day) }) - 86400
  M.open_date(os.date("%Y-%m-%d", time))
end

--- Navigate to the next journal entry (after the current one)
function M.next()
  local current_date = M._current_journal_date()
  if not current_date then
    vim.notify("VimSeq: current buffer is not a journal entry", vim.log.levels.WARN)
    return
  end

  local year, month, day = current_date:match("(%d+)-(%d+)-(%d+)")
  if not year then return end
  local time = os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day) }) + 86400
  M.open_date(os.date("%Y-%m-%d", time))
end

--- Get the date string from the current buffer if it's a journal entry
---@return string|nil
function M._current_journal_date()
  local buf_path = vim.api.nvim_buf_get_name(0)
  local cfg = config.get()
  local journal_prefix = cfg.vault_path .. "/" .. cfg.journal_dir .. "/"

  if buf_path:sub(1, #journal_prefix) ~= journal_prefix then
    return nil
  end

  local filename = buf_path:sub(#journal_prefix + 1)
  return filename:match("^(%d%d%d%d%-%d%d%-%d%d)%.md$")
end

return M
