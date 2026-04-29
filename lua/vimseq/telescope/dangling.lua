local M = {}

local db = require("vimseq.db")
local sync = require("vimseq.db.sync")

--- Telescope picker: show all dangling (unresolved) wiki links
---@param opts table|nil Telescope options
function M.picker(opts)
  opts = opts or {}

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local dangling = db.get_dangling_links()

  pickers.new(opts, {
    prompt_title = "Dangling Links (unresolved)",
    finder = finders.new_table({
      results = dangling,
      entry_maker = function(entry)
        local display = string.format(
          "[[%s]] in %s (L%d)",
          entry.target_title,
          entry.source_title,
          entry.line_number
        )
        return {
          value = entry,
          display = display,
          ordinal = entry.target_title .. " " .. entry.source_title,
          path = sync.abs_path(entry.source_path),
          lnum = entry.line_number,
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
          -- Navigate to the source file at the line with the dangling link
          vim.cmd("edit " .. vim.fn.fnameescape(selection.path))
          if selection.lnum then
            pcall(vim.api.nvim_win_set_cursor, 0, { selection.lnum, 0 })
          end
        end
      end)
      return true
    end,
  }):find()
end

return M
