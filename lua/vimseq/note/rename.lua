local M = {}

local config = require("vimseq.config")
local db = require("vimseq.db")
local sync = require("vimseq.db.sync")
local note_mod = require("vimseq.note")

--- Rename the current note: updates filename, frontmatter title, and all backlinks
---@param new_title string|nil If nil, prompts the user
function M.rename(new_title)
  local current = note_mod.current_note()
  if not current then
    vim.notify("VimSeq: current buffer is not a vault note", vim.log.levels.WARN)
    return
  end

  local old_title = current.title
  local cfg = config.get()

  -- Prompt if no title given
  if not new_title or new_title == "" then
    vim.ui.input({ prompt = "Rename note: ", default = old_title }, function(input)
      if input and input ~= "" and input ~= old_title then
        M._do_rename(current, old_title, input)
      end
    end)
  else
    M._do_rename(current, old_title, new_title)
  end
end

--- Internal: perform the rename operation
---@param current table Note record from DB
---@param old_title string
---@param new_title string
function M._do_rename(current, old_title, new_title)
  local cfg = config.get()
  local old_abs = sync.abs_path(current.path)
  local new_rel = sync.title_to_path(new_title)
  local new_abs = sync.abs_path(new_rel)

  -- Check if target already exists
  if vim.loop.fs_stat(new_abs) then
    vim.notify("VimSeq: a note with that name already exists", vim.log.levels.ERROR)
    return
  end

  -- 1. Rename the file
  local ok = vim.loop.fs_rename(old_abs, new_abs)
  if not ok then
    vim.notify("VimSeq: failed to rename file", vim.log.levels.ERROR)
    return
  end

  -- 2. Update the database
  db.rename_note(old_title, new_title, new_rel)

  -- 3. Update frontmatter in the renamed file
  M._update_frontmatter_title(new_abs, new_title)

  -- 4. Update all files that contain [[old_title]] links
  local backlinks = db.get_backlinks(new_title) -- already updated in DB
  -- We need the files that HAD [[old_title]] — get them before the DB update
  -- Since we already updated DB, we scan files directly
  M._update_backlink_files(cfg.vault_path, old_title, new_title)

  -- 5. Re-sync affected files
  sync.full_sync()

  -- 6. Open the renamed file
  vim.cmd("edit " .. vim.fn.fnameescape(new_abs))

  vim.notify(
    string.format('VimSeq: renamed "%s" -> "%s"', old_title, new_title),
    vim.log.levels.INFO
  )
end

--- Update the title in a file's YAML frontmatter
---@param abs_path string
---@param new_title string
function M._update_frontmatter_title(abs_path, new_title)
  local fd = vim.loop.fs_open(abs_path, "r", 438)
  if not fd then return end
  local stat = vim.loop.fs_fstat(fd)
  if not stat then
    vim.loop.fs_close(fd)
    return
  end
  local content = vim.loop.fs_read(fd, stat.size, 0)
  vim.loop.fs_close(fd)

  if not content then return end

  -- Replace title in frontmatter
  local updated = content:gsub("(%-%-%-\n.-title:%s*)(.-)(\n)", "%1" .. new_title .. "%3", 1)

  -- Also update H1 heading if it matches old content
  -- (simple: replace first # heading)
  updated = updated:gsub("\n(#%s+)(.-)(\n)", "\n%1" .. new_title .. "%3", 1)

  fd = vim.loop.fs_open(abs_path, "w", 438)
  if fd then
    vim.loop.fs_write(fd, updated, 0)
    vim.loop.fs_close(fd)
  end
end

--- Scan all .md files in vault and replace [[old_title]] with [[new_title]]
---@param vault_path string
---@param old_title string
---@param new_title string
function M._update_backlink_files(vault_path, old_title, new_title)
  -- Use ripgrep if available for speed, otherwise fall back to Lua scan
  local old_link = "[[" .. old_title .. "]]"
  local new_link = "[[" .. new_title .. "]]"
  local old_alias_pattern = "%[%[" .. vim.pesc(old_title) .. "|"
  local new_alias_prefix = "[[" .. new_title .. "|"

  local function process_file(path)
    local fd = vim.loop.fs_open(path, "r", 438)
    if not fd then return end
    local stat = vim.loop.fs_fstat(fd)
    if not stat then
      vim.loop.fs_close(fd)
      return
    end
    local content = vim.loop.fs_read(fd, stat.size, 0)
    vim.loop.fs_close(fd)
    if not content then return end

    local changed = false
    local updated = content

    -- Replace [[old_title]] with [[new_title]]
    if updated:find(old_link, 1, true) then
      updated = updated:gsub("%[%[" .. vim.pesc(old_title) .. "%]%]", new_link)
      changed = true
    end

    -- Replace [[old_title|alias]] with [[new_title|alias]]
    if updated:find(old_alias_pattern) then
      updated = updated:gsub("%[%[" .. vim.pesc(old_title) .. "|", new_alias_prefix)
      changed = true
    end

    if changed then
      fd = vim.loop.fs_open(path, "w", 438)
      if fd then
        vim.loop.fs_write(fd, updated, 0)
        vim.loop.fs_close(fd)
      end
    end
  end

  -- Walk vault
  local function walk(dir)
    local handle = vim.loop.fs_scandir(dir)
    if not handle then return end
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then break end
      local full = dir .. "/" .. name
      if type == "file" and name:match("%.md$") then
        process_file(full)
      elseif type == "directory" and not name:match("^%.") then
        walk(full)
      end
    end
  end

  walk(vault_path)
end

return M
