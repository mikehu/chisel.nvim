local M = {}

local defaults = {
	keymap = "<leader>ci",
	exclude_filetypes = { "oil" },
	backend = "claude",
	claude = {
		cmd = "claude",
		args = {
			"--verbose",
			"--output-format",
			"stream-json",
			"--include-partial-messages",
			"--no-session-persistence",
		},
	},
	ui = {
		spinner = {
			hl_group = "DiagnosticVirtualTextWarn",
		},
	},
}

M.values = vim.deepcopy(defaults)

function M.setup(opts)
	M.values = vim.tbl_deep_extend("force", defaults, opts or {})
end

return M
