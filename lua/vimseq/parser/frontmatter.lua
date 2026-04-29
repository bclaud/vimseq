local M = {}

--- Parse YAML frontmatter from file content
--- Handles the basic subset needed for VimSeq: title, tags, aliases, date
---@param content string Full file content
---@return table|nil Parsed frontmatter {title, tags, aliases, date} or nil if no frontmatter
function M.parse(content)
  -- Check for frontmatter delimiters
  if not content:match("^%-%-%-\n") then
    return nil
  end

  local fm_end = content:find("\n%-%-%-", 4)
  if not fm_end then
    return nil
  end

  local fm_text = content:sub(5, fm_end - 1) -- skip the opening ---\n

  local result = {
    title = nil,
    tags = {},
    aliases = {},
    date = nil,
  }

  for line in fm_text:gmatch("[^\n]+") do
    -- title: My Note Title
    local title = line:match("^title:%s*(.+)$")
    if title then
      result.title = title:match("^%s*(.-)%s*$") -- trim
    end

    -- date: 2026-04-29
    local date = line:match("^date:%s*(.+)$")
    if date then
      result.date = date:match("^%s*(.-)%s*$")
    end

    -- tags: [tag1, tag2] or tags: [tag1]
    local tags_str = line:match("^tags:%s*%[(.-)%]")
    if tags_str then
      for tag in tags_str:gmatch("[^,%s]+") do
        table.insert(result.tags, tag)
      end
    end

    -- aliases: [alias1, alias2]
    local aliases_str = line:match("^aliases:%s*%[(.-)%]")
    if aliases_str then
      for alias in aliases_str:gmatch("[^,]+") do
        alias = alias:match("^%s*(.-)%s*$") -- trim
        if alias ~= "" then
          table.insert(result.aliases, alias)
        end
      end
    end
  end

  return result
end

--- Extract the title from a Markdown file
--- Priority: frontmatter title > first H1 heading > filename
---@param content string File content
---@param filename string Filename without extension
---@return string
function M.extract_title(content, filename)
  -- Try frontmatter
  local fm = M.parse(content)
  if fm and fm.title then
    return fm.title
  end

  -- Try first H1
  local h1 = content:match("\n?#%s+(.+)")
  if h1 then
    return h1:match("^%s*(.-)%s*$")
  end

  -- Fallback: humanize filename
  local title = filename:gsub("%-", " ")
  -- Capitalize first letter of each word
  title = title:gsub("(%a)([%w_']*)", function(first, rest)
    return first:upper() .. rest
  end)

  return title
end

return M
