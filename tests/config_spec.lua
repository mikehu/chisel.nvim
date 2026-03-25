require("tests.helpers").install()

local config = require("chisel.config")

describe("chisel.config", function()
	before_each(function()
		-- Reset to defaults before each test
		config.setup({})
	end)

	describe("setup", function()
		it("uses defaults when called with no args", function()
			config.setup()
			assert.are.equal("claude", config.values.backend)
			assert.are.equal("<leader>ci", config.values.keymap)
			assert.are.equal("claude", config.values.claude.cmd)
		end)

		it("merges user overrides into defaults", function()
			config.setup({ backend = "codex", keymap = "<leader>cc" })
			assert.are.equal("codex", config.values.backend)
			assert.are.equal("<leader>cc", config.values.keymap)
		end)

		it("deep merges nested tables", function()
			config.setup({
				claude = { cmd = "/usr/local/bin/claude" },
			})
			-- Overridden value
			assert.are.equal("/usr/local/bin/claude", config.values.claude.cmd)
			-- Default args preserved
			assert.is_true(#config.values.claude.args > 0)
			assert.are.equal("--verbose", config.values.claude.args[1])
		end)

		it("preserves default exclude_filetypes when not overridden", function()
			config.setup({})
			assert.is_true(vim.tbl_contains(config.values.exclude_filetypes, "oil"))
		end)

		it("allows overriding exclude_filetypes", function()
			config.setup({ exclude_filetypes = { "markdown", "help" } })
			assert.is_false(vim.tbl_contains(config.values.exclude_filetypes, "oil"))
			assert.is_true(vim.tbl_contains(config.values.exclude_filetypes, "markdown"))
		end)

		it("allows overriding spinner highlight group", function()
			config.setup({ ui = { spinner = { hl_group = "Error" } } })
			assert.are.equal("Error", config.values.ui.spinner.hl_group)
		end)
	end)
end)
