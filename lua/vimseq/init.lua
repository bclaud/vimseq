local M = {}

---@type boolean
M._initialized = false

--- Setup VimSeq with user configuration
---@param opts table|nil User configuration overrides
function M.setup(opts)
  if M._initialized then
    return
  end

  -- 1. Merge config
  local config = require("vimseq.config")
  config.setup(opts)
  local cfg = config.get()

  -- 2. Ensure vault directory exists
  vim.fn.mkdir(cfg.vault_path, "p")
  vim.fn.mkdir(cfg.vault_path .. "/" .. cfg.journal_dir, "p")
  vim.fn.mkdir(cfg.vault_path .. "/" .. cfg.assets_dir, "p")

  -- 3. Initialize database
  local db = require("vimseq.db")
  db.setup(cfg.db_path)

  -- 4. Run initial index
  local sync = require("vimseq.db.sync")
  sync.full_sync()

  -- 5. Register commands and keybindings
  require("vimseq.commands").setup()

  -- 6. Setup syntax highlighting
  require("vimseq.ui.highlights").setup()

  -- 7. Setup auto-indexing on save
  if cfg.auto_index then
    M._setup_auto_index()
  end

  -- 8. Optional: image.nvim integration
  if cfg.enable_images then
    local ok = pcall(require, "image")
    if ok then
      require("vimseq.ui.image").setup()
    end
  end

  -- 9. Optional: nvim-cmp source
  if cfg.enable_cmp then
    local cmp_ok = pcall(require, "cmp")
    if cmp_ok then
      require("vimseq.cmp").register()
    end
  end

  -- 10. Register Telescope extension
  pcall(function()
    require("vimseq.telescope")
  end)

  M._initialized = true
  vim.notify("VimSeq initialized: " .. cfg.vault_path, vim.log.levels.INFO)
end

--- Setup autocommand to re-index on file save within the vault
function M._setup_auto_index()
  local cfg = require("vimseq.config").get()
  local group = vim.api.nvim_create_augroup("VimSeqAutoIndex", { clear = true })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = cfg.vault_path .. "/*.md",
    callback = function(ev)
      local sync = require("vimseq.db.sync")
      sync.sync_file(ev.file)
    end,
    desc = "VimSeq: re-index note on save",
  })
end

return M
