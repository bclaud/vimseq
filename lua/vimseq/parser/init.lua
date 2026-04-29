--- Unified parsing API for VimSeq
--- Re-exports wikilink and frontmatter parsers for convenience

local M = {}

M.wikilink = require("vimseq.parser.wikilink")
M.frontmatter = require("vimseq.parser.frontmatter")

--- Parse a complete note file and return structured data
---@param content string Full file content
---@param filename string Filename without extension (for title fallback)
---@return table {title, links, tags, frontmatter}
function M.parse_note(content, filename)
  local fm = M.frontmatter.parse(content)
  local title = M.frontmatter.extract_title(content, filename)
  local links = M.wikilink.extract_from_content(content)
  local tags = M.wikilink.extract_tags(content)

  -- Merge frontmatter tags with inline tags
  if fm and fm.tags then
    local seen = {}
    for _, t in ipairs(tags) do
      seen[t] = true
    end
    for _, t in ipairs(fm.tags) do
      if not seen[t] then
        table.insert(tags, t)
      end
    end
  end

  return {
    title = title,
    links = links,
    tags = tags,
    frontmatter = fm,
  }
end

return M
