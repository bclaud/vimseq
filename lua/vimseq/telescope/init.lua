--- Telescope extension registration for VimSeq

local M = {}

--- Register the telescope extension (called lazily)
function M.register()
  local ok, telescope = pcall(require, "telescope")
  if not ok then
    return
  end

  telescope.register_extension({
    setup = function() end,
    exports = {
      notes = require("vimseq.telescope.notes").picker,
      backlinks = require("vimseq.telescope.backlinks").picker,
      tags = require("vimseq.telescope.tags").picker,
      dangling = require("vimseq.telescope.dangling").picker,
    },
  })
end

-- Auto-register on require
M.register()

return M
