local M = {}

--- Capture buffer metadata for the given line range (visual selection).
--- @param start_line number 1-indexed start line
--- @param end_line number 1-indexed end line
--- @return table ctx
function M.capture(start_line, end_line)
	local bufnr = vim.api.nvim_get_current_buf()

	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
	local file_path = vim.api.nvim_buf_get_name(bufnr)
	local ft = vim.bo[bufnr].filetype

	return {
		bufnr = bufnr,
		start_line = start_line,
		end_line = end_line,
		lines = lines,
		text = table.concat(lines, "\n"),
		file_path = file_path,
		filetype = ft,
		mode = "replace",
	}
end

--- Capture buffer metadata for whole-file editing via Claude's Edit tool.
--- @return table ctx
function M.capture_file()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed
	local file_path = vim.api.nvim_buf_get_name(bufnr)
	local ft = vim.bo[bufnr].filetype

	return {
		bufnr = bufnr,
		start_line = cursor_line,
		end_line = cursor_line,
		file_path = file_path,
		filetype = ft,
		mode = "file",
	}
end

return M
