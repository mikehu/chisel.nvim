--- Tests for chisel.context module.
--- These tests require running inside Neovim (via plenary test harness)
--- since context.lua calls nvim_buf_get_lines, nvim_get_current_buf, etc.

local context = require("chisel.context")

describe("chisel.context", function()
	local bufnr

	before_each(function()
		-- Create a scratch buffer with known content
		bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(bufnr)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"line 1",
			"line 2",
			"line 3",
			"line 4",
			"line 5",
		})
		vim.bo[bufnr].filetype = "lua"
	end)

	after_each(function()
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end)

	describe("capture", function()
		it("captures the correct line range", function()
			local ctx = context.capture(2, 4)
			assert.are.equal(bufnr, ctx.bufnr)
			assert.are.equal(2, ctx.start_line)
			assert.are.equal(4, ctx.end_line)
			assert.are.equal(3, #ctx.lines)
			assert.are.equal("line 2", ctx.lines[1])
			assert.are.equal("line 4", ctx.lines[3])
		end)

		it("swaps start/end if inverted", function()
			local ctx = context.capture(4, 2)
			assert.are.equal(2, ctx.start_line)
			assert.are.equal(4, ctx.end_line)
			assert.are.equal(3, #ctx.lines)
		end)

		it("joins lines into text field", function()
			local ctx = context.capture(1, 2)
			assert.are.equal("line 1\nline 2", ctx.text)
		end)

		it("captures single line", function()
			local ctx = context.capture(3, 3)
			assert.are.equal(1, #ctx.lines)
			assert.are.equal("line 3", ctx.lines[1])
		end)

		it("sets mode to replace", function()
			local ctx = context.capture(1, 5)
			assert.are.equal("replace", ctx.mode)
		end)

		it("captures filetype", function()
			local ctx = context.capture(1, 1)
			assert.are.equal("lua", ctx.filetype)
		end)
	end)

	describe("capture_file", function()
		it("sets mode to file", function()
			vim.api.nvim_win_set_cursor(0, { 3, 0 })
			local ctx = context.capture_file()
			assert.are.equal("file", ctx.mode)
		end)

		it("uses cursor line for start and end", function()
			vim.api.nvim_win_set_cursor(0, { 3, 0 })
			local ctx = context.capture_file()
			assert.are.equal(3, ctx.start_line)
			assert.are.equal(3, ctx.end_line)
		end)

		it("captures the correct buffer", function()
			local ctx = context.capture_file()
			assert.are.equal(bufnr, ctx.bufnr)
		end)

		it("does not include lines array", function()
			local ctx = context.capture_file()
			assert.is_nil(ctx.lines)
			assert.is_nil(ctx.text)
		end)
	end)
end)
