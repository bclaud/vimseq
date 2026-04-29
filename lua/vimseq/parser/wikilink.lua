local M = {}

--- Pattern for [[wiki links]] — captures the full link content between [[ and ]]
-- Handles: [[Page Name]], [[Page Name|Display Text]]
local WIKILINK_PATTERN = "%[%[(.-)%]%]"

--- Parse a single wiki link string into its components
---@param link_text string The text between [[ and ]] e.g. "Page Name|Display Text"
---@return string target The target page title
---@return string|nil display The display text (nil if no alias)
function M.parse_link(link_text)
  local pipe_pos = link_text:find("|")
  if pipe_pos then
    local target = link_text:sub(1, pipe_pos - 1):match("^%s*(.-)%s*$") -- trim
    local display = link_text:sub(pipe_pos + 1):match("^%s*(.-)%s*$")  -- trim
    return target, display
  end
  return link_text:match("^%s*(.-)%s*$"), nil -- trim whitespace
end

--- Extract all wiki links from a single line of text
---@param line string
---@return table[] List of {target, display, col_start, col_end}
function M.extract_from_line(line)
  local links = {}
  local search_start = 1

  while true do
    local match_start, match_end, content = line:find(WIKILINK_PATTERN, search_start)
    if not match_start then
      break
    end

    local target, display = M.parse_link(content)
    if target and target ~= "" then
      table.insert(links, {
        target = target,
        display = display,
        col_start = match_start,   -- 1-indexed byte position of first [
        col_end = match_end,       -- 1-indexed byte position of last ]
        raw = content,
      })
    end

    search_start = match_end + 1
  end

  return links
end

--- Extract all wiki links from a buffer's content (string or lines table)
---@param content string|string[] Full file content or list of lines
---@return table[] List of {target, display, line_number, col_start, col_end}
function M.extract_from_content(content)
  local lines
  if type(content) == "string" then
    lines = vim.split(content, "\n")
  else
    lines = content
  end

  local all_links = {}
  for i, line in ipairs(lines) do
    local line_links = M.extract_from_line(line)
    for _, link in ipairs(line_links) do
      link.line_number = i
      table.insert(all_links, link)
    end
  end

  return all_links
end

--- Get the wiki link under the cursor in the current buffer
---@return table|nil {target, display, line_number, col_start, col_end} or nil if cursor not on a link
function M.get_link_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local col = cursor[2] + 1 -- convert 0-indexed to 1-indexed

  local links = M.extract_from_line(line)
  for _, link in ipairs(links) do
    if col >= link.col_start and col <= link.col_end then
      link.line_number = cursor[1]
      return link
    end
  end

  return nil
end

--- Extract hashtag-style tags from text (e.g. #tag, #my-tag)
---@param content string
---@return string[] List of tag strings (without the # prefix)
function M.extract_tags(content)
  local tags = {}
  local seen = {}
  -- Match #tag but not inside [[links]] or code blocks
  -- Simple approach: match #word patterns
  for tag in content:gmatch("#([%w%-_]+)") do
    if not seen[tag] then
      table.insert(tags, tag)
      seen[tag] = true
    end
  end
  return tags
end

return M
