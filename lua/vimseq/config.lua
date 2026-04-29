local M = {}

---@class VimSeqConfig
---@field vault_path string Absolute path to the notes vault directory
---@field db_path string|nil Path to SQLite database (default: vault_path/.vimseq.db)
---@field journal_dir string Subdirectory for daily journal notes (relative to vault_path)
---@field assets_dir string Subdirectory for images/assets (relative to vault_path)
---@field note_name_fn fun(title: string): string Function to convert title to filename
---@field template_fn fun(title: string): string Function to generate new note content
---@field journal_template_fn fun(date: string): string Function to generate journal content
---@field keymaps table<string, string|false> Keymap overrides (set to false to disable)
---@field enable_images boolean Enable image.nvim integration
---@field enable_cmp boolean Enable nvim-cmp source
---@field backlinks_width number Width of the backlinks side panel
---@field auto_index boolean Auto re-index on BufWritePost

--- Convert a title to a kebab-case filename
---@param title string
---@return string
local function default_note_name(title)
  local name = title:lower()
  name = name:gsub("[^%w%s%-]", "") -- remove non-alphanumeric except spaces and hyphens
  name = name:gsub("%s+", "-")       -- spaces to hyphens
  name = name:gsub("%-+", "-")       -- collapse multiple hyphens
  name = name:gsub("^%-+", "")       -- trim leading hyphens
  name = name:gsub("%-+$", "")       -- trim trailing hyphens
  return name
end

--- Generate default note content with YAML frontmatter
---@param title string
---@return string
local function default_template(title)
  local date = os.date("%Y-%m-%d")
  return table.concat({
    "---",
    "title: " .. title,
    "date: " .. date,
    "tags: []",
    "aliases: []",
    "---",
    "",
    "# " .. title,
    "",
    "",
  }, "\n")
end

--- Generate default journal content
---@param date string e.g. "2026-04-29"
---@return string
local function default_journal_template(date)
  return table.concat({
    "---",
    "title: " .. date,
    "date: " .. date,
    "tags: [journal]",
    "---",
    "",
    "# " .. date,
    "",
    "",
  }, "\n")
end

---@type VimSeqConfig
M.defaults = {
  vault_path = vim.fn.expand("~/vimseq"),
  db_path = nil, -- will default to vault_path/.vimseq.db
  journal_dir = "journal",
  assets_dir = "assets",
  note_name_fn = default_note_name,
  template_fn = default_template,
  journal_template_fn = default_journal_template,
  enable_images = true,
  enable_cmp = true,
  backlinks_width = 40,
  auto_index = true,
  keymaps = {
    follow_link = "<CR>",
    go_back = "<BS>",
    toggle_backlinks = "<leader>vb",
    new_note = "<leader>vn",
    search_notes = "<leader>vf",
    search_tags = "<leader>vt",
    open_journal = "<leader>vj",
    rename_note = "<leader>vr",
    paste_image = "<leader>vi",
    search_backlinks = "<leader>vl",
    dangling_links = "<leader>vd",
    full_text_search = "<leader>vs",
  },
}

--- The active merged configuration
---@type VimSeqConfig
M.current = vim.deepcopy(M.defaults)

--- Merge user config with defaults
---@param user_config table|nil
function M.setup(user_config)
  user_config = user_config or {}
  M.current = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), user_config)

  -- Default db_path inside the vault
  if not M.current.db_path then
    M.current.db_path = M.current.vault_path .. "/.vimseq.db"
  end

  -- Ensure vault_path is expanded
  M.current.vault_path = vim.fn.expand(M.current.vault_path)
  M.current.db_path = vim.fn.expand(M.current.db_path)
end

--- Get the current config
---@return VimSeqConfig
function M.get()
  return M.current
end

return M
