# VimSeq

A Neovim-native knowledge base inspired by [LogSeq](https://logseq.com/), built entirely in Lua. Brings bidirectional `[[wiki links]]`, a SQLite-backed index, daily journals, and Markdown-first note-taking directly into your Neovim workflow -- no Electron app required.

## Why

LogSeq is great but depends on a desktop application. VimSeq implements the same core principles -- bidirectional linking, daily journals, graph-aware navigation -- using plain Markdown files and Neovim as the interface.

## Features

- **Bidirectional `[[wiki links]]`** with alias support (`[[Page|display text]]`)
- **SQLite-backed index** for fast backlink queries, tag lookups, and dangling link detection
- **Backlinks panel** -- side split showing all notes that reference the current page
- **Daily journals** -- auto-created `YYYY-MM-DD.md` entries
- **Telescope integration** -- fuzzy search notes, backlinks, tags, and dangling links
- **Syntax highlighting** -- concealed `[[brackets]]`, colored links (blue = exists, red = dangling), `#tag` highlighting
- **Image support** -- inline rendering via [image.nvim](https://github.com/3rd/image.nvim) and clipboard paste
- **nvim-cmp source** -- completion triggered by `[[`
- **Note rename** -- renames the file and updates all backlinks across the vault
- **Incremental indexing** -- re-indexes only changed files on save

## Requirements

- Neovim >= 0.9
- [sqlite.lua](https://github.com/kkharji/sqlite.lua) and `sqlite3` system library
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional, for pickers)
- [image.nvim](https://github.com/3rd/image.nvim) (optional, for inline images)
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) (optional, for `[[` completion)

## Install

### Nix flake

```nix
# flake.nix inputs
vimseq = {
  url = "github:bclaud/vimseq";
  inputs.nixpkgs.follows = "nixpkgs";
};

# Apply the overlay
overlays = [ inputs.vimseq.overlays.default ];

# Add to neovim plugins
programs.neovim.plugins = with pkgs.vimPlugins; [
  sqlite-lua
  pkgs.vimPlugins.vimseq
];

# Set LIBSQLITE so sqlite.lua finds the shared library
home.sessionVariables = {
  LIBSQLITE = "${pkgs.sqlite.out}/lib/libsqlite3.so";
};
```

### lazy.nvim

```lua
{
  "bclaud/vimseq",
  dependencies = {
    "kkharji/sqlite.lua",
    "nvim-telescope/telescope.nvim", -- optional
    "3rd/image.nvim",                -- optional
    "hrsh7th/nvim-cmp",              -- optional
  },
  config = function()
    require("vimseq").setup({
      vault_path = "~/notes",
    })
  end,
}
```

## Setup

```lua
require("vimseq").setup({
  vault_path = "~/notes",         -- where your notes live
  journal_dir = "journal",        -- subdirectory for daily journals
  assets_dir = "assets",          -- subdirectory for images
  backlinks_width = 40,           -- width of the backlinks side panel
  auto_index = true,              -- re-index on save
})
```

All options have sensible defaults. Only `vault_path` is worth setting explicitly.

## Keybindings

All mappings use the `<leader>v` prefix. Buffer-local mappings only activate inside vault `.md` files.

### Buffer-local (inside vault)

| Key | Action |
|-----|--------|
| `<CR>` | Follow `[[wiki link]]` under cursor |
| `<BS>` | Go back in link history |
| `<leader>vb` | Toggle backlinks panel |
| `<leader>vr` | Rename current note |
| `<leader>vi` | Paste image from clipboard |

### Global

| Key | Action |
|-----|--------|
| `<leader>vn` | Create new note |
| `<leader>vf` | Find notes (Telescope) |
| `<leader>vt` | Browse tags (Telescope) |
| `<leader>vj` | Open today's journal |
| `<leader>vl` | Search backlinks (Telescope) |
| `<leader>vd` | Show dangling links (Telescope) |
| `<leader>vs` | Full-text search in vault (Telescope live_grep) |

All keybindings are configurable via the `keymaps` table in `setup()`. Set any key to `false` to disable it.

## Commands

| Command | Description |
|---------|-------------|
| `:VimSeqNew [title]` | Create a new note |
| `:VimSeqRename [title]` | Rename current note, update all backlinks |
| `:VimSeqToday` | Open today's journal |
| `:VimSeqYesterday` | Open yesterday's journal |
| `:VimSeqTomorrow` | Open tomorrow's journal |
| `:VimSeqBacklinks` | Toggle backlinks panel |
| `:VimSeqReindex` | Force full vault re-index |
| `:VimSeqPasteImage` | Paste clipboard image into assets/ |
| `:VimSeqSearch` | Search notes (Telescope) |
| `:VimSeqTags` | Browse tags (Telescope) |
| `:VimSeqDangling` | Show unresolved links (Telescope) |

## How it works

Notes are plain Markdown files stored in `vault_path`. On startup, VimSeq scans the vault and builds a SQLite index of all notes, `[[links]]`, and `#tags`. The index is updated incrementally on every file save.

Links are resolved by title (case-insensitive). `[[My Note]]` links to the file whose title is "My Note" -- determined from YAML frontmatter, the first `# heading`, or the filename.

Files are named in kebab-case by default: a note titled "My Cool Idea" becomes `my-cool-idea.md`. This is configurable via `note_name_fn` in setup.

## License

MIT
