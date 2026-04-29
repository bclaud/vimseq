local M = {}

local wikilink = require("vimseq.parser.wikilink")
local config = require("vimseq.config")

--- Namespace for wiki link extmarks
local ns_name = "vimseq_links"
local ns_id = nil

--- Get or create the namespace
---@return integer
local function get_ns()
  if not ns_id then
    ns_id = vim.api.nvim_create_namespace(ns_name)
  end
  return ns_id
end

--- Define highlight groups
local function define_highlights()
  -- Wiki link text (the visible part)
  vim.api.nvim_set_hl(0, "VimSeqLink", {
    fg = "#83a598",    -- gruvbox blue-ish (fits gruvbox-material)
    underline = true,
    default = true,
  })

  -- Wiki link brackets (concealed)
  vim.api.nvim_set_hl(0, "VimSeqLinkBracket", {
    fg = "#504945",    -- gruvbox dim
    default = true,
  })

  -- Dangling link (target doesn't exist)
  vim.api.nvim_set_hl(0, "VimSeqDanglingLink", {
    fg = "#fb4934",    -- gruvbox red
    underline = true,
    italic = true,
    default = true,
  })

  -- Tag highlight
  vim.api.nvim_set_hl(0, "VimSeqTag", {
    fg = "#b8bb26",    -- gruvbox green
    italic = true,
    default = true,
  })
end

--- Apply wiki link highlights to a single buffer
---@param bufnr integer
function M.highlight_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ns = get_ns()

  -- Clear existing extmarks
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for i, line in ipairs(lines) do
    local row = i - 1 -- 0-indexed

    -- Highlight wiki links
    local links = wikilink.extract_from_line(line)
    for _, link in ipairs(links) do
      local col_start = link.col_start - 1 -- 0-indexed
      local col_end = link.col_end         -- exclusive

      -- Check if the link target exists in the DB
      local db_ok, db = pcall(require, "vimseq.db")
      local hl_group = "VimSeqLink"
      if db_ok and db._db then
        local target = db.get_note_by_title(link.target)
        if not target then
          hl_group = "VimSeqDanglingLink"
        end
      end

      -- Opening [[ — conceal
      vim.api.nvim_buf_set_extmark(bufnr, ns, row, col_start, {
        end_col = col_start + 2,
        conceal = "",
      })

      -- The link text
      local text_start = col_start + 2
      local text_end
      if link.display then
        -- For [[target|display]], conceal the "target|" part and only show display
        local pipe_offset = link.raw:find("|")
        text_end = col_end - 2
        -- Conceal from [[ to just after |
        vim.api.nvim_buf_set_extmark(bufnr, ns, row, col_start, {
          end_col = col_start + 2 + pipe_offset,
          conceal = "",
        })
        text_start = col_start + 2 + pipe_offset
      else
        text_end = col_end - 2
      end

      -- Highlight the visible text
      vim.api.nvim_buf_set_extmark(bufnr, ns, row, text_start, {
        end_col = text_end,
        hl_group = hl_group,
      })

      -- Closing ]] — conceal
      vim.api.nvim_buf_set_extmark(bufnr, ns, row, col_end - 2, {
        end_col = col_end,
        conceal = "",
      })
    end

    -- Highlight #tags
    local search_start = 1
    while true do
      local tag_start, tag_end, tag = line:find("#([%w%-_]+)", search_start)
      if not tag_start then break end

      -- Make sure it's not inside a wiki link or heading
      local is_heading = line:match("^#+%s")
      local inside_link = false
      for _, link in ipairs(links) do
        if tag_start >= link.col_start and tag_end <= link.col_end then
          inside_link = true
          break
        end
      end

      if not is_heading and not inside_link then
        vim.api.nvim_buf_set_extmark(bufnr, ns, row, tag_start - 1, {
          end_col = tag_end,
          hl_group = "VimSeqTag",
        })
      end

      search_start = tag_end + 1
    end
  end
end

--- Setup highlights and autocommands
function M.setup()
  define_highlights()

  local cfg = config.get()

  -- Enable conceallevel in vault markdown files
  local group = vim.api.nvim_create_augroup("VimSeqHighlights", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    group = group,
    pattern = cfg.vault_path .. "/*.md",
    callback = function(ev)
      -- Set conceal for the vault
      vim.wo.conceallevel = 2
      vim.wo.concealcursor = "nc"

      -- Apply highlights
      M.highlight_buffer(ev.buf)
    end,
    desc = "VimSeq: apply wiki link highlights",
  })

  -- Also re-highlight on text changes (for live feedback)
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    pattern = cfg.vault_path .. "/*.md",
    callback = function(ev)
      -- Debounce: only re-highlight if we haven't recently
      M._schedule_highlight(ev.buf)
    end,
    desc = "VimSeq: live re-highlight wiki links",
  })
end

--- Debounced highlight scheduling
M._highlight_timer = nil

function M._schedule_highlight(bufnr)
  if M._highlight_timer then
    M._highlight_timer:stop()
  end
  M._highlight_timer = vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      M.highlight_buffer(bufnr)
    end
  end, 200) -- 200ms debounce
end

return M
