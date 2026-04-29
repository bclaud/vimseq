--- nvim-cmp source for VimSeq wiki link completion
--- Triggers on [[ and suggests note titles from the SQLite index

local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

source.get_trigger_characters = function()
  return { "[" }
end

source.get_keyword_pattern = function()
  return [=[\%(\[\[\)\zs[^\]]*]=]
end

source.complete = function(self, params, callback)
  -- Only trigger if the line has [[ before cursor
  local line = params.context.cursor_before_line
  local trigger_pos = line:find("%[%[[^%]]*$")

  if not trigger_pos then
    callback({ items = {}, isIncomplete = false })
    return
  end

  -- Get the partial input after [[
  local input = line:sub(trigger_pos + 2)

  -- Query all notes from the database
  local ok, db = pcall(require, "vimseq.db")
  if not ok or not db._db then
    callback({ items = {}, isIncomplete = false })
    return
  end

  local notes = db.get_all_notes()
  local items = {}

  for _, note in ipairs(notes) do
    table.insert(items, {
      label = note.title,
      kind = 18, -- Reference
      detail = note.path,
      insertText = note.title .. "]]",
      filterText = note.title,
      sortText = note.title:lower(),
    })
  end

  callback({ items = items, isIncomplete = false })
end

--- Register as a cmp source
local function register()
  local cmp_ok, cmp = pcall(require, "cmp")
  if not cmp_ok then
    return
  end

  cmp.register_source("vimseq", source.new())
end

return {
  source = source,
  register = register,
}
