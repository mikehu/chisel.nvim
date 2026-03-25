local config = require("chisel.config")
local context = require("chisel.context")
local session = require("chisel.session")

local M = {}

--- @type ChiselSession|nil
local active_session = nil

--- @type snacks.win|nil
local review_win = nil

--- Prompt for instruction and start a session with the given context.
--- @param ctx table
local function prompt_and_start(ctx)
	-- Place cursor at the context line so the input anchors there
	vim.api.nvim_win_set_cursor(0, { ctx.start_line, 0 })

	Snacks.input({
		prompt = "⛏️ chisel> ",
		win = { relative = "cursor", row = -1, col = 0, width = 80 },
	}, function(instruction)
		if not instruction or instruction == "" then
			return
		end

		-- Abort any existing session before starting a new one
		if active_session and not active_session.done then
			session.abort(active_session)
		end

		active_session = session.start(ctx, instruction)
	end)
end

--- Check if the current buffer should be excluded from chisel.
--- @return boolean
local function is_excluded()
	local ft = vim.bo.filetype
	local bt = vim.bo.buftype
	-- Skip special buffers (floats, terminals, help, etc.)
	if bt ~= "" then return true end
	return vim.tbl_contains(config.values.exclude_filetypes, ft)
end

--- Start a chisel session from a visual selection.
--- @param line1 number 1-indexed start line (from command range)
--- @param line2 number 1-indexed end line (from command range)
function M.start(line1, line2)
	if is_excluded() then return end
	local ctx = context.capture(line1, line2)
	if #ctx.lines == 0 then
		vim.notify("chisel: no selection", vim.log.levels.WARN)
		return
	end
	prompt_and_start(ctx)
end

--- Start a chisel session for whole-file editing (normal mode).
function M.start_file()
	if is_excluded() then return end
	local ctx = context.capture_file()
	prompt_and_start(ctx)
end

--- Toggle a review float showing the last chisel response.
function M.review()
	-- Toggle: close if already open
	if review_win and review_win:valid() then
		review_win:close()
		review_win = nil
		return
	end

	local text = session.last_response
	if not text then
		vim.notify("chisel: no response to review", vim.log.levels.INFO)
		return
	end

	local lines = vim.split(text, "\n", { plain = true })
	local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.4))
	height = math.max(height, 10)

	review_win = Snacks.win({
		text = text,
		ft = "markdown",
		row = -1,
		width = 0,
		height = height,
		border = "top",
		title = " ⛏️ chisel response ",
		title_pos = "left",
		backdrop = false,
		enter = true,
		bo = { modifiable = false },
		wo = { conceallevel = 2, wrap = true },
		keys = {
			q = "close",
			["<Esc>"] = "close",
		},
		on_close = function()
			review_win = nil
		end,
	})
end

--- Abort the current active session.
function M.abort()
	if active_session and not active_session.done then
		session.abort(active_session)
		vim.notify("chisel: aborted", vim.log.levels.INFO)
	end
end

--- Setup chisel with optional config overrides and register commands.
--- @param opts? table
function M.setup(opts)
	config.setup(opts)

	vim.api.nvim_create_user_command("Chisel", function(cmd_opts)
		M.start(cmd_opts.line1, cmd_opts.line2)
	end, { range = true, desc = "Chisel inline edit" })

	vim.api.nvim_create_user_command("ChiselFile", function()
		M.start_file()
	end, { desc = "Chisel file edit" })

	vim.api.nvim_create_user_command("ChiselAbort", function()
		M.abort()
	end, { desc = "Abort chisel session" })

	vim.api.nvim_create_user_command("ChiselReview", function()
		M.review()
	end, { desc = "Review last chisel response" })
end

return M
