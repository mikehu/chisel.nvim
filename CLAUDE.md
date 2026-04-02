# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

chisel.nvim is a Neovim plugin for surgical inline code editing powered by AI CLI tools (Claude CLI, with Codex support planned). Users select code (or work on a whole file), type a natural-language instruction, and the AI edits the file directly. Ideal for targeted per-file edits and explanations.

## Plugin Structure (lazy.nvim compatible)

The `lua/` directory at root is the standard Neovim plugin layout. `require("chisel")` resolves to `lua/chisel/init.lua`.

## Architecture

**Entry point** — `init.lua` exposes `setup()` (registers the `:Chisel` command with subcommands `file`, `abort`, `review`), `start()` (visual selection), `start_file()` (whole file), and manages the single active session.

**Flow**: User command → `context.capture()` / `context.capture_file()` builds a context table → `Snacks.input` prompt → `session.start()` → `backend/claude.spawn()` → streams NDJSON → callbacks update fidget progress + extmark spinners → on completion, buffer is reloaded from disk (`vim.cmd("edit")`).

**Key design decisions:**
- Claude edits files on disk via its Edit tool, then the buffer is reloaded — there's no in-buffer diff/patch application.
- The buffer is auto-saved before spawning Claude so the file on disk matches what the user sees.
- Only one active session at a time; starting a new one aborts the previous.
- The `CLAUDECODE` env var is temporarily cleared before spawning to avoid subprocess conflicts.
- stdin is immediately closed after spawn (`chanclose`).

**Modules:**
- `config.lua` — merges user opts with defaults (keymap, backend, claude CLI args, UI settings)
- `context.lua` — captures buffer metadata for visual selection (`mode="replace"`) or whole file (`mode="file"`)
- `session.lua` — session lifecycle (start/abort), wires backend callbacks to UI updates
- `backend/claude.lua` — spawns `claude` CLI with `--output-format stream-json`, parses NDJSON stream events (`content_block_delta`, `message_stop`, `result`, `assistant`)
- `ui/extmarks.lua` — orchestrates block + text spinners over the selected range
- `ui/block_spinner.lua` — animated diagonal-stripe overlay using extmarks with box-drawing borders
- `ui/text_spinner.lua` — braille-character spinner centered on the selection

## Dependencies

Runtime dependencies (must be available in the user's Neovim config):
- **snacks.nvim** (`Snacks.input`, `Snacks.win`, `Snacks.notify`) — UI primitives (input prompt, review float, notifications)
- **fidget.nvim** — progress indicator showing Claude's thinking text
- **Claude CLI** (`claude`) — must be on PATH; invoked with `--dangerously-skip-permissions`

## Development

**Testing:** Uses plenary.nvim's busted-style test harness. Requires Neovim + plenary.nvim installed.

```bash
make test                                        # Run all tests
make test-file FILE=tests/config_spec.lua        # Run a single test file
```

Test files live in `tests/`. Tests for pure-logic modules (`config_spec`, `backend_claude_spec`) can mock `vim.*` via `tests/helpers.lua`. Tests that need real Neovim APIs (`context_spec`) run inside the plenary harness.

**Backend internals exposed for testing:** `backend/claude.lua` exposes `_build_cmd` and `_process_line` as module methods (prefixed with `_` to signal internal use).

**Logging:** Debug logs write to `vim.fn.stdpath("log") .. "/chisel.log"` (cleared each run). Check this file when debugging backend/streaming issues.

**Testing changes locally:** Symlink or point lazy.nvim to the local directory:
```lua
{ dir = "/path/to/chisel.nvim" }
```
Then `:Lazy reload chisel.nvim` or restart Neovim.
