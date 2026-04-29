-- VimSeq: A Neovim-native knowledge base with bidirectional links
-- Lazy-load trigger: only setup commands and autocommands here

if vim.g.loaded_vimseq then
  return
end
vim.g.loaded_vimseq = true

-- Register user commands (actual logic deferred until setup() is called)
vim.api.nvim_create_user_command("VimSeqSetup", function()
  require("vimseq").setup()
end, { desc = "Initialize VimSeq with default config" })

-- The main entry point: users call require("vimseq").setup({...})
-- Commands are registered after setup() is called in commands.lua
