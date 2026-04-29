-- Tests for the frontmatter parser
-- Run with: nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

describe("frontmatter parser", function()
  local frontmatter = require("vimseq.parser.frontmatter")

  describe("parse", function()
    it("parses basic frontmatter", function()
      local content = table.concat({
        "---",
        "title: My Note",
        "date: 2026-04-29",
        "tags: [tag1, tag2]",
        "aliases: [alias1, alias2]",
        "---",
        "",
        "# My Note",
        "",
        "Content here",
      }, "\n")

      local fm = frontmatter.parse(content)
      assert.is_not_nil(fm)
      assert.equals("My Note", fm.title)
      assert.equals("2026-04-29", fm.date)
      assert.equals(2, #fm.tags)
      assert.equals("tag1", fm.tags[1])
      assert.equals("tag2", fm.tags[2])
      assert.equals(2, #fm.aliases)
      assert.equals("alias1", fm.aliases[1])
      assert.equals("alias2", fm.aliases[2])
    end)

    it("returns nil for no frontmatter", function()
      local fm = frontmatter.parse("# Just a heading\n\nSome content")
      assert.is_nil(fm)
    end)

    it("handles empty tags", function()
      local content = "---\ntitle: Test\ntags: []\n---\n\nContent"
      local fm = frontmatter.parse(content)
      assert.is_not_nil(fm)
      assert.equals(0, #fm.tags)
    end)
  end)

  describe("extract_title", function()
    it("uses frontmatter title", function()
      local content = "---\ntitle: FM Title\n---\n\n# H1 Title\n"
      local title = frontmatter.extract_title(content, "filename")
      assert.equals("FM Title", title)
    end)

    it("falls back to H1", function()
      local content = "# H1 Title\n\nSome content"
      local title = frontmatter.extract_title(content, "filename")
      assert.equals("H1 Title", title)
    end)

    it("falls back to filename", function()
      local content = "Some content without heading"
      local title = frontmatter.extract_title(content, "my-cool-note")
      assert.equals("My Cool Note", title)
    end)
  end)
end)
