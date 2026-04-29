local M = {}

local db = require("vimseq.db")
local config = require("vimseq.config")
local sync = require("vimseq.db.sync")

--- Buffer number for the backlinks panel (nil if not open)
---@type integer|nil
M._buf = nil

--- Window ID for the backlinks panel (nil if not open)
---@type integer|nil
M._win = nil

--- The title we're currently showing backlinks for
---@type string|nil
M._current_title = nil

--- Cached backlink entries for navigation
---@type table[]
M._entries = {}

--- Check if the backlinks panel is currently open and valid
---@return boolean
function M.is_open()
  return M._win ~= nil
    and vim.api.nvim_win_is_valid(M._win)
    and M._buf ~= nil
    and vim.api.nvim_buf_is_valid(M._buf)
end

--- Open the backlinks side panel
function M.open()
  if M.is_open() then
    M.refresh()
    return
  end

  local cfg = config.get()

  -- Create a new buffer for the backlinks panel
  M._buf = vim.api.nvim_create_buf(false, true) -- not listed, scratch
  vim.api.nvim_buf_set_option(M._buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M._buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(M._buf, "swapfile", false)
  vim.api.nvim_buf_set_option(M._buf, "filetype", "vimseq-backlinks")

  -- Open a vertical split on the right
  vim.cmd("botright " .. cfg.backlinks_width .. "vsplit")
  M._win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(M._win, M._buf)

  -- Window options
  vim.api.nvim_win_set_option(M._win, "number", false)
  vim.api.nvim_win_set_option(M._win, "relativenumber", false)
  vim.api.nvim_win_set_option(M._win, "signcolumn", "no")
  vim.api.nvim_win_set_option(M._win, "wrap", true)
  vim.api.nvim_win_set_option(M._win, "cursorline", true)
  vim.api.nvim_win_set_option(M._win, "winfixwidth", true)

  -- Set up keymaps in the backlinks buffer
  vim.keymap.set("n", "<CR>", function()
    M._follow_entry()
  end, { buffer = M._buf, desc = "VimSeq: follow backlink" })

  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = M._buf, desc = "VimSeq: close backlinks" })

  -- Populate with backlinks
  M.refresh()

  -- Go back to the previous window
  vim.cmd("wincmd p")

  -- Set up auto-refresh on BufEnter
  M._setup_auto_refresh()
end

--- Close the backlinks panel
function M.close()
  if M._win and vim.api.nvim_win_is_valid(M._win) then
    vim.api.nvim_win_close(M._win, true)
  end
  M._win = nil
  M._buf = nil
  M._current_title = nil
  M._entries = {}
end

--- Toggle the backlinks panel
function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

--- Refresh the backlinks panel content
function M.refresh()
  if not M.is_open() then
    return
  end

  -- Get the title of the note in the main window
  -- We need to find the "other" window (not the backlinks panel)
  local title = nil
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= M._win then
      local buf = vim.api.nvim_win_get_buf(win)
      local buf_path = vim.api.nvim_buf_get_name(buf)
      local cfg = config.get()
      if buf_path:sub(1, #cfg.vault_path) == cfg.vault_path then
        local rel_path = buf_path:sub(#cfg.vault_path + 2)
        local note_record = db.get_note_by_path(rel_path)
        if note_record then
          title = note_record.title
          break
        end
      end
    end
  end

  if not title then
    M._render_empty("No vault note in focus")
    return
  end

  M._current_title = title

  -- Query backlinks
  local backlinks = db.get_backlinks(title)
  M._entries = backlinks

  -- Render
  local lines = {}
  table.insert(lines, " Backlinks: " .. title)
  table.insert(lines, string.rep("─", 38))

  if #backlinks == 0 then
    table.insert(lines, "")
    table.insert(lines, " No backlinks found")
  else
    table.insert(lines, "")
    for i, bl in ipairs(backlinks) do
      local line = string.format(" %d. %s", i, bl.source_title)
      table.insert(lines, line)
      local detail = string.format("    L%d in %s", bl.line_number, bl.source_path)
      table.insert(lines, detail)
    end
  end

  table.insert(lines, "")
  table.insert(lines, string.rep("─", 38))
  table.insert(lines, " <CR> to follow | q to close")

  vim.api.nvim_buf_set_option(M._buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M._buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M._buf, "modifiable", false)

  -- Apply highlights
  local ns = vim.api.nvim_create_namespace("vimseq_backlinks")
  vim.api.nvim_buf_clear_namespace(M._buf, ns, 0, -1)
  if #lines > 0 then
    vim.api.nvim_buf_add_highlight(M._buf, ns, "Title", 0, 0, -1)
  end
  if #lines > 1 then
    vim.api.nvim_buf_add_highlight(M._buf, ns, "Comment", 1, 0, -1)
  end
  -- Highlight entry titles
  for i, _ in ipairs(backlinks) do
    local line_idx = 3 + (i - 1) * 2 -- 0-indexed
    if line_idx < #lines then
      vim.api.nvim_buf_add_highlight(M._buf, ns, "Function", line_idx, 0, -1)
    end
    local detail_idx = line_idx + 1
    if detail_idx < #lines then
      vim.api.nvim_buf_add_highlight(M._buf, ns, "Comment", detail_idx, 0, -1)
    end
  end
end

--- Render an empty/message state
---@param message string
function M._render_empty(message)
  if not M._buf or not vim.api.nvim_buf_is_valid(M._buf) then
    return
  end
  vim.api.nvim_buf_set_option(M._buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M._buf, 0, -1, false, {
    " Backlinks",
    string.rep("─", 38),
    "",
    " " .. message,
  })
  vim.api.nvim_buf_set_option(M._buf, "modifiable", false)
  M._entries = {}
end

--- Follow the backlink entry under the cursor
function M._follow_entry()
  if not M.is_open() then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(M._win)
  local line_num = cursor[1] -- 1-indexed

  -- Entries start at line 4 (after header), each takes 2 lines
  local entry_idx = math.floor((line_num - 4) / 2) + 1

  if entry_idx >= 1 and entry_idx <= #M._entries then
    local entry = M._entries[entry_idx]
    local abs_path = sync.abs_path(entry.source_path)

    -- Switch to the main editing window first
    vim.cmd("wincmd p")
    vim.cmd("edit " .. vim.fn.fnameescape(abs_path))

    -- Jump to the line where the link appears
    if entry.line_number and entry.line_number > 0 then
      pcall(vim.api.nvim_win_set_cursor, 0, { entry.line_number, 0 })
    end
  end
end

--- Setup autocommand to refresh panel when switching buffers
function M._setup_auto_refresh()
  local group = vim.api.nvim_create_augroup("VimSeqBacklinks", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "*.md",
    callback = function()
      -- Don't refresh if we're entering the backlinks buffer itself
      if vim.api.nvim_get_current_buf() ~= M._buf then
        vim.defer_fn(function()
          M.refresh()
        end, 100)
      end
    end,
    desc = "VimSeq: refresh backlinks panel",
  })
end

return M
