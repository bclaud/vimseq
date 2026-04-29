local M = {}

local db = require("vimseq.db")
local sync = require("vimseq.db.sync")

--- Telescope picker: browse tags, then show notes for selected tag
---@param opts table|nil Telescope options
function M.picker(opts)
  opts = opts or {}

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local tags = db.get_all_tags()

  pickers.new(opts, {
    prompt_title = "VimSeq Tags",
    finder = finders.new_table({
      results = tags,
      entry_maker = function(entry)
        local display = string.format("#%s (%d)", entry.tag, entry.count)
        return {
          value = entry,
          display = display,
          ordinal = entry.tag,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          -- Open a second picker showing notes with this tag
          M._notes_for_tag(selection.value.tag, opts)
        end
      end)
      return true
    end,
  }):find()
end

--- Sub-picker: show all notes with a specific tag
---@param tag string
---@param opts table|nil
function M._notes_for_tag(tag, opts)
  opts = opts or {}

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local notes = db.get_notes_by_tag(tag)

  pickers.new(opts, {
    prompt_title = "Notes tagged #" .. tag,
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
