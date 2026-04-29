local M = {}

local db = require("vimseq.db")
local sync = require("vimseq.db.sync")

--- Telescope picker: search all notes by title
---@param opts table|nil Telescope options
function M.picker(opts)
  opts = opts or {}

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local notes = db.get_all_notes()

  pickers.new(opts, {
    prompt_title = "VimSeq Notes",
    finder = finders.new_table({
      results = notes,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.title,
          ordinal = entry.title .. " " .. entry.path,
          path = sync.abs_path(entry.path),
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = conf.file_previewer(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          vim.cmd("edit " .. vim.fn.fnameescape(selection.path))
        end
      end)
      return true
    end,
  }):find()
end

return M
