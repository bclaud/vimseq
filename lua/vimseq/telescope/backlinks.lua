local M = {}

local db = require("vimseq.db")
local sync = require("vimseq.db.sync")
local note_mod = require("vimseq.note")

--- Telescope picker: show backlinks for the current note
---@param opts table|nil Telescope options
function M.picker(opts)
  opts = opts or {}

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local title = note_mod.current_title()
  if not title then
    vim.notify("VimSeq: current buffer is not a vault note", vim.log.levels.WARN)
    return
  end

  local backlinks = db.get_backlinks(title)

  pickers.new(opts, {
    prompt_title = "Backlinks: " .. title,
    finder = finders.new_table({
      results = backlinks,
      entry_maker = function(entry)
        local display = string.format("%s (L%d)", entry.source_title, entry.line_number)
        return {
          value = entry,
          display = display,
          ordinal = entry.source_title .. " " .. entry.source_path,
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
