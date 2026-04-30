local M = {}

local config = require("vimseq.config")

--- Register all user commands and buffer-local keymaps
function M.setup()
  local cfg = config.get()

  -- ================================================================
  -- User commands (global)
  -- ================================================================

  vim.api.nvim_create_user_command("VimSeqNew", function(args)
    local title = args.args
    if title == "" then
      vim.ui.input({ prompt = "New note title: " }, function(input)
        if input and input ~= "" then
          local note = require("vimseq.note")
          local abs_path = note.create(input)
          note.open(abs_path)
        end
      end)
    else
      local note = require("vimseq.note")
      local abs_path = note.create(title)
      note.open(abs_path)
    end
  end, { nargs = "?", desc = "VimSeq: create a new note" })

  vim.api.nvim_create_user_command("VimSeqRename", function(args)
    local new_title = args.args ~= "" and args.args or nil
    require("vimseq.note.rename").rename(new_title)
  end, { nargs = "?", desc = "VimSeq: rename current note" })

  vim.api.nvim_create_user_command("VimSeqToday", function()
    require("vimseq.journal").today()
  end, { desc = "VimSeq: open today's journal" })

  vim.api.nvim_create_user_command("VimSeqYesterday", function()
    require("vimseq.journal").yesterday()
  end, { desc = "VimSeq: open yesterday's journal" })

  vim.api.nvim_create_user_command("VimSeqTomorrow", function()
    require("vimseq.journal").tomorrow()
  end, { desc = "VimSeq: open tomorrow's journal" })

  vim.api.nvim_create_user_command("VimSeqBacklinks", function()
    require("vimseq.ui.backlinks").toggle()
  end, { desc = "VimSeq: toggle backlinks panel" })

  vim.api.nvim_create_user_command("VimSeqReindex", function()
    require("vimseq.db.sync").full_sync()
    vim.notify("VimSeq: vault re-indexed", vim.log.levels.INFO)
  end, { desc = "VimSeq: force full vault re-index" })

  vim.api.nvim_create_user_command("VimSeqReset", function()
    require("vimseq.db").reset()
    vim.notify("VimSeq: database reset and re-indexed", vim.log.levels.INFO)
  end, { desc = "VimSeq: delete database, recreate schema, and re-index vault" })

  vim.api.nvim_create_user_command("VimSeqPasteImage", function()
    require("vimseq.ui.image").paste_image()
  end, { desc = "VimSeq: paste image from clipboard" })

  vim.api.nvim_create_user_command("VimSeqSearch", function()
    require("vimseq.telescope.notes").picker()
  end, { desc = "VimSeq: search notes (Telescope)" })

  vim.api.nvim_create_user_command("VimSeqTags", function()
    require("vimseq.telescope.tags").picker()
  end, { desc = "VimSeq: browse tags (Telescope)" })

  vim.api.nvim_create_user_command("VimSeqDangling", function()
    require("vimseq.telescope.dangling").picker()
  end, { desc = "VimSeq: show dangling links (Telescope)" })

  vim.api.nvim_create_user_command("VimSeqSearchBacklinks", function()
    require("vimseq.telescope.backlinks").picker()
  end, { desc = "VimSeq: search backlinks (Telescope)" })

  -- ================================================================
  -- Buffer-local keymaps (only in vault .md files)
  -- ================================================================

  local group = vim.api.nvim_create_augroup("VimSeqKeymaps", { clear = true })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = cfg.vault_path .. "/*.md",
    callback = function(ev)
      M._set_buffer_keymaps(ev.buf)
    end,
    desc = "VimSeq: set buffer-local keymaps",
  })

  -- ================================================================
  -- Global keymaps (always available, for vault-level operations)
  -- ================================================================

  local km = cfg.keymaps

  if km.new_note then
    vim.keymap.set("n", km.new_note, "<cmd>VimSeqNew<cr>",
      { desc = "VimSeq: [v]imseq [n]ew note" })
  end

  if km.search_notes then
    vim.keymap.set("n", km.search_notes, "<cmd>VimSeqSearch<cr>",
      { desc = "VimSeq: [v]imseq [f]ind notes" })
  end

  if km.search_tags then
    vim.keymap.set("n", km.search_tags, "<cmd>VimSeqTags<cr>",
      { desc = "VimSeq: [v]imseq [t]ags" })
  end

  if km.open_journal then
    vim.keymap.set("n", km.open_journal, "<cmd>VimSeqToday<cr>",
      { desc = "VimSeq: [v]imseq [j]ournal today" })
  end

  if km.dangling_links then
    vim.keymap.set("n", km.dangling_links, "<cmd>VimSeqDangling<cr>",
      { desc = "VimSeq: [v]imseq [d]angling links" })
  end

  if km.search_backlinks then
    vim.keymap.set("n", km.search_backlinks, "<cmd>VimSeqSearchBacklinks<cr>",
      { desc = "VimSeq: [v]imseq back[l]inks search" })
  end

  if km.full_text_search then
    vim.keymap.set("n", km.full_text_search, function()
      -- Use telescope live_grep scoped to vault
      local ok, builtin = pcall(require, "telescope.builtin")
      if ok then
        builtin.live_grep({ cwd = cfg.vault_path })
      end
    end, { desc = "VimSeq: [v]imseq [s]earch text" })
  end
end

--- Set buffer-local keymaps for vault markdown files
---@param bufnr integer
function M._set_buffer_keymaps(bufnr)
  local cfg = config.get()
  local km = cfg.keymaps
  local map_opts = { buffer = bufnr, silent = true }

  if km.follow_link then
    vim.keymap.set("n", km.follow_link, function()
      require("vimseq.note.navigate").follow_link_or_noop()
    end, vim.tbl_extend("force", map_opts, { desc = "VimSeq: follow wiki link" }))
  end

  if km.go_back then
    vim.keymap.set("n", km.go_back, function()
      require("vimseq.note.navigate").go_back()
    end, vim.tbl_extend("force", map_opts, { desc = "VimSeq: go back" }))
  end

  if km.toggle_backlinks then
    vim.keymap.set("n", km.toggle_backlinks, "<cmd>VimSeqBacklinks<cr>",
      vim.tbl_extend("force", map_opts, { desc = "VimSeq: toggle backlinks panel" }))
  end

  if km.rename_note then
    vim.keymap.set("n", km.rename_note, "<cmd>VimSeqRename<cr>",
      vim.tbl_extend("force", map_opts, { desc = "VimSeq: rename note" }))
  end

  if km.paste_image then
    vim.keymap.set("n", km.paste_image, "<cmd>VimSeqPasteImage<cr>",
      vim.tbl_extend("force", map_opts, { desc = "VimSeq: paste image" }))
  end
end

return M
