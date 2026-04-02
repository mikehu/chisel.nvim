# chisel.nvim

Surgical inline code editing for Neovim, powered by AI.

Select code, describe what you want, and chisel refines it in place — no chat windows, no diff previews, no context switching. One instruction, one edit, done.

## How It Works

1. **Select** code in visual mode (or use `:Chisel file` for whole-file context)
2. **Describe** the change you want in plain English
3. **Wait** — a spinner overlays the selected lines while the AI works
4. **Done** — your file is updated in place

chisel delegates the actual editing to an AI CLI tool (currently Claude CLI, with Codex support planned). The AI receives your selection, your instruction, and uses its Edit tool to surgically modify the file on disk. The buffer reloads automatically.

## Use Cases

- **Refactor** — "extract this into a helper function"
- **Fix** — "this has an off-by-one error"
- **Transform** — "convert to async/await"
- **Explain** — "add comments explaining this logic"
- **Generate** — "add error handling for the network call"

## Requirements

- Neovim >= 0.10
- [snacks.nvim](https://github.com/folke/snacks.nvim) — input prompt, floating windows, notifications
- [fidget.nvim](https://github.com/j-hui/fidget.nvim) — progress indicator
- [Claude CLI](https://docs.anthropic.com/en/docs/claude-cli) — must be installed and on your `PATH`

## Installation

### lazy.nvim

```lua
{
  "yourusername/chisel.nvim",
  dependencies = {
    "folke/snacks.nvim",
    "j-hui/fidget.nvim",
  },
  keys = {
    { "<leader>ci", ":Chisel<CR>", mode = "v", desc = "Chisel selection" },
    { "<leader>ci", ":Chisel file<CR>", mode = "n", desc = "Chisel file" },
  },
  config = function()
    require("chisel").setup()
  end,
}
```

## Configuration

All options are optional. Defaults:

```lua
require("chisel").setup({
  keymap = "<leader>ci",
  exclude_filetypes = { "oil" },
  backend = "claude",             -- "claude" (codex planned)
  claude = {
    cmd = "claude",
    args = {
      "--verbose",
      "--output-format", "stream-json",
      "--include-partial-messages",
      "--no-session-persistence",
    },
  },
  ui = {
    spinner = {
      hl_group = "DiagnosticVirtualTextWarn",
    },
  },
})
```

## Commands

| Command | Description |
|---|---|
| `:Chisel` | Edit selected lines (visual mode) |
| `:Chisel file` | Edit with whole-file context (normal mode, cursor provides location hint) |
| `:Chisel abort` | Cancel the active session |
| `:Chisel review` | Toggle a float showing the last response |

## Backends

### Claude CLI (current)

Uses the `claude` CLI with streaming JSON output. Claude receives your selection as context and edits the file directly using its Edit tool with `--dangerously-skip-permissions`.

### Codex (planned)

OpenAI Codex CLI support is on the roadmap.

## Debugging

Logs are written to `vim.fn.stdpath("log") .. "/chisel.log"` and cleared each run. Check this file if edits aren't applying or the spinner hangs.
