-- Minimal init for running tests with plenary
-- Usage: nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

-- Add the plugin to the runtimepath
vim.opt.rtp:append(".")

-- Add plenary to runtimepath (adjust if needed)
local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 1 then
  vim.opt.rtp:append(plenary_path)
end

-- Try other common plenary locations
local alt_paths = {
  vim.fn.stdpath("data") .. "/site/pack/packer/start/plenary.nvim",
  vim.fn.stdpath("data") .. "/plugged/plenary.nvim",
  "/nix/store/*/vimPlugins/plenary-nvim", -- nix-managed
}
for _, p in ipairs(alt_paths) do
  if vim.fn.isdirectory(p) == 1 then
    vim.opt.rtp:append(p)
    break
  end
end
