local M = {}

local config = require("vimseq.config")
local db = require("vimseq.db")
local sync = require("vimseq.db.sync")
local note = require("vimseq.note")
local wikilink = require("vimseq.parser.wikilink")

--- Navigation history stack
---@type table[] List of {path, cursor} entries
M._history = {}
M._max_history = 50

--- Push current position onto navigation history
local function push_history()
  local buf_path = vim.api.nvim_buf_get_name(0)
  local cursor = vim.api.nvim_win_get_cursor(0)
  table.insert(M._history, { path = buf_path, cursor = cursor })
  if #M._history > M._max_history then
    table.remove(M._history, 1)
  end
end

--- Follow the [[wiki link]] under the cursor
function M.follow_link()
  local link = wikilink.get_link_under_cursor()
  if not link then
    vim.notify("VimSeq: no wiki link under cursor", vim.log.levels.WARN)
    return
  end

  local target_title = link.target
  local cfg = config.get()

  -- Try to find the note in the database
  local target_note = db.get_note_by_title(target_title)

  if target_note then
    -- Note exists — navigate to it
    push_history()
    local abs_path = sync.abs_path(target_note.path)
    note.open(abs_path)
  else
    -- Note doesn't exist — offer to create it
    local choice = vim.fn.confirm(
      'Note "' .. target_title .. '" does not exist. Create it?',
      "&Yes\n&No",
      1
    )
    if choice == 1 then
      push_history()
      local abs_path = note.create(target_title)
      note.open(abs_path)
    end
  end
end

--- Go back in navigation history
function M.go_back()
  if #M._history == 0 then
    vim.notify("VimSeq: no more history", vim.log.levels.INFO)
    return
  end

  local entry = table.remove(M._history)
  if entry.path and entry.path ~= "" then
    vim.cmd("edit " .. vim.fn.fnameescape(entry.path))
    pcall(vim.api.nvim_win_set_cursor, 0, entry.cursor)
  end
end

--- Follow link or go back, depending on context
--- If cursor is on a link, follow it. Otherwise do nothing.
function M.follow_link_or_noop()
  local link = wikilink.get_link_under_cursor()
  if link then
    M.follow_link()
  end
end

return M
