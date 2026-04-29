local M = {}

local config = require("vimseq.config")

--- Setup image.nvim integration for vault markdown files
function M.setup()
  -- image.nvim handles markdown images automatically via its built-in
  -- markdown integration. We just need to ensure it's configured to work
  -- with our vault path.
  --
  -- If image.nvim is installed and configured, it will automatically
  -- render ![alt](path) images in markdown files.
  --
  -- We provide an additional command: VimSeqPasteImage
  -- which saves clipboard image to assets/ and inserts the link.

  -- No additional setup needed — image.nvim's markdown integration
  -- handles rendering automatically.
end

--- Paste an image from the clipboard into the vault's assets directory
--- and insert a Markdown image link at the cursor position.
function M.paste_image()
  local cfg = config.get()
  local assets_dir = cfg.vault_path .. "/" .. cfg.assets_dir

  -- Ensure assets directory exists
  vim.fn.mkdir(assets_dir, "p")

  -- Generate a filename based on timestamp
  local filename = os.date("%Y%m%d-%H%M%S") .. ".png"
  local abs_path = assets_dir .. "/" .. filename

  -- Use xclip to save clipboard image (you have xclip in your nix config)
  local result = vim.fn.system({
    "xclip", "-selection", "clipboard", "-t", "image/png", "-o",
  })

  if vim.v.shell_error ~= 0 then
    vim.notify("VimSeq: no image in clipboard", vim.log.levels.WARN)
    return
  end

  -- Write the image data to file
  local fd = vim.loop.fs_open(abs_path, "w", 438)
  if not fd then
    vim.notify("VimSeq: failed to save image", vim.log.levels.ERROR)
    return
  end
  vim.loop.fs_write(fd, result, 0)
  vim.loop.fs_close(fd)

  -- Compute relative path from the current note to the image
  local buf_path = vim.api.nvim_buf_get_name(0)
  local buf_dir = buf_path:match("(.+)/[^/]+$") or cfg.vault_path
  local rel_image_path = cfg.assets_dir .. "/" .. filename

  -- If the note is in a subdirectory, adjust the relative path
  local buf_rel = buf_path:sub(#cfg.vault_path + 2)
  local depth = 0
  for _ in buf_rel:gmatch("/") do
    depth = depth + 1
  end
  if depth > 0 then
    rel_image_path = string.rep("../", depth) .. rel_image_path
  end

  -- Insert markdown image link at cursor
  local line = string.format("![image](%s)", rel_image_path)
  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_lines(0, cursor[1], cursor[1], false, { line })
  vim.api.nvim_win_set_cursor(0, { cursor[1] + 1, 0 })

  vim.notify("VimSeq: image saved to " .. rel_image_path, vim.log.levels.INFO)
end

return M
