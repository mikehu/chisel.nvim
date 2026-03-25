local BlockSpinner = require("chisel.ui.block_spinner")
local TextSpinner = require("chisel.ui.text_spinner")
local config = require("chisel.config")

local M = {}

--- @class ChiselExtmarkState
--- @field ns_id number Namespace ID
--- @field block_spinner VirtualTextBlockSpinner
--- @field text_spinner VirtualTextSpinner

--- Show spinners on the selected range.
--- @param ctx table The selection context (bufnr, start_line, end_line)
--- @return ChiselExtmarkState
function M.show(ctx)
	local ns_id = vim.api.nvim_create_namespace("chisel_" .. tostring(os.clock()))
	local spinner_hl = config.values.ui.spinner.hl_group

	local block = BlockSpinner.new({
		bufnr = ctx.bufnr,
		ns_id = ns_id,
		start_line = ctx.start_line,
		end_line = ctx.end_line,
		min_width = 40,
		opts = { hl_group = spinner_hl, extmark = { virt_text_pos = "overlay" } },
	})
	block:start()

	local mid_line = ctx.start_line + math.floor((ctx.end_line - ctx.start_line) / 2)
	local text = TextSpinner.new({
		bufnr = ctx.bufnr,
		ns_id = ns_id,
		line_num = mid_line,
		width = block.width,
		opts = {
			hl_group = spinner_hl,
			spinner_text = "  ⛏️ chiseling...",
			extmark = { virt_text_pos = "overlay", priority = 1001 },
		},
	})
	text:start()

	return {
		ns_id = ns_id,
		block_spinner = block,
		text_spinner = text,
	}
end

--- Hide spinners and clean up the namespace.
--- @param state ChiselExtmarkState
--- @param bufnr number
function M.hide(state, bufnr)
	state.block_spinner:stop()
	state.text_spinner:stop()
	vim.schedule(function()
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_clear_namespace(bufnr, state.ns_id, 0, -1)
		end
	end)
end

return M
