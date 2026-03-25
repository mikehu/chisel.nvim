local config = require("chisel.config")

local M = {}

local log_path = vim.fn.stdpath("log") .. "/chisel.log"
local function log(msg)
	local f = io.open(log_path, "a")
	if f then
		f:write(os.date("%H:%M:%S") .. " " .. msg .. "\n")
		f:close()
	end
end

--- Build the command list for spawning claude.
--- @param prompt string The user's instruction
--- @param ctx table The selection context from context.lua
--- @return string[] cmd The command and arguments list
function M._build_cmd(prompt, ctx)
	local cfg = config.values.claude
	local system_context

	if ctx.mode == "file" then
		system_context = string.format(
			"You are a code editing assistant.\n"
				.. "The user is working in `%s` (filetype: %s). Their cursor is at line %d.\n"
				.. "Use the Edit tool to make targeted changes. Only change what's needed.\n"
				.. "If other files also need changes, mention that in your response.",
			ctx.file_path,
			ctx.filetype or "",
			ctx.start_line
		)
	else
		system_context = string.format(
			"You are a code editing assistant.\n"
				.. "The user has selected the following code from `%s` (lines %d-%d, filetype: %s):\n```%s\n%s\n```\n"
				.. "Use the Edit tool to make targeted changes to this file. Focus on the selected code,\n"
				.. "but you may also edit other parts of the file if needed for correctness.\n"
				.. "If other files also need changes, mention that in your response.",
			ctx.file_path,
			ctx.start_line,
			ctx.end_line,
			ctx.filetype or "",
			ctx.filetype or "",
			ctx.text
		)
	end

	local cmd = { cfg.cmd, "-p", prompt }
	for _, arg in ipairs(cfg.args) do
		table.insert(cmd, arg)
	end

	table.insert(cmd, "--tools")
	table.insert(cmd, "Read,Edit")
	table.insert(cmd, "--dangerously-skip-permissions")

	table.insert(cmd, "--append-system-prompt")
	table.insert(cmd, system_context)
	return cmd
end

--- Process a single complete NDJSON line.
--- @param line string A complete JSON line
--- @param callbacks table Callback functions
--- @param state table Accumulator for streaming deltas
function M._process_line(line, callbacks, state)
	if line == "" then
		return
	end

	line = line:gsub("\r", "")

	local ok, event = pcall(vim.json.decode, line)
	if not ok then
		return
	end

	-- Unwrap stream_event wrapper
	if event.type == "stream_event" and event.event then
		event = event.event
	end

	if event.type == "content_block_delta" and event.delta then
		if event.delta.type == "text_delta" and event.delta.text then
			state.text = state.text .. event.delta.text
			callbacks.on_text(state.text)
		elseif event.delta.type == "thinking_delta" and event.delta.thinking then
			state.thinking = state.thinking .. event.delta.thinking
			callbacks.on_thinking(state.thinking)
		end
	elseif event.type == "message_stop" then
		-- Don't fire on_done here — in multi-turn tool use, message_stop fires
		-- after each turn. Wait for the result event or on_exit instead.
		log("message_stop: text_len=" .. #state.text)
	elseif event.type == "result" then
		log("result event")
		if not state.done then
			state.done = true
			callbacks.on_done(state.text)
		end
	elseif event.type == "assistant" and event.message and event.message.content then
		-- Fallback: accumulated assistant message (overrides delta accumulation)
		for _, block in ipairs(event.message.content) do
			if block.type == "text" then
				state.text = block.text
				callbacks.on_text(state.text)
			end
		end
	end
end

--- Spawn a claude subprocess with streaming NDJSON output.
--- @param prompt string The user's instruction
--- @param ctx table The selection context
--- @param callbacks table Callback functions
--- @return number|nil job_id The job ID, or nil if spawn failed
function M.spawn(prompt, ctx, callbacks)
	-- Clear log for fresh run
	local f = io.open(log_path, "w")
	if f then f:close() end

	local cmd = M._build_cmd(prompt, ctx)
	local buffer = ""
	local state = { text = "", thinking = "" }

	-- Temporarily clear CLAUDECODE so the subprocess doesn't refuse to start
	local saved_claudecode = vim.env.CLAUDECODE
	vim.env.CLAUDECODE = nil

	local job_id = vim.fn.jobstart(cmd, {
		stdout_buffered = false,
		on_stdout = function(_, data, _)
			if not data then
				return
			end
			for i, chunk in ipairs(data) do
				if i == 1 then
					buffer = buffer .. chunk
				else
					M._process_line(buffer, callbacks, state)
					buffer = chunk
				end
			end
		end,
		on_exit = function(_, exit_code, _)
			log("on_exit: code=" .. tostring(exit_code) .. " buffer_len=" .. #buffer .. " text_len=" .. #state.text)
			if buffer ~= "" then
				M._process_line(buffer, callbacks, state)
				buffer = ""
			end
			-- If we never got a result event, fire on_done now as fallback
			if not state.done then
				state.done = true
				callbacks.on_done(state.text)
			end
			if exit_code ~= 0 then
				vim.schedule(function()
					callbacks.on_error("claude exited with code " .. exit_code)
				end)
			end
		end,
	})

	vim.env.CLAUDECODE = saved_claudecode

	if job_id and job_id > 0 then
		vim.fn.chanclose(job_id, "stdin")
	end

	if not job_id or job_id <= 0 then
		callbacks.on_error("failed to start claude — is it on your PATH?")
		return nil
	end

	return job_id
end

--- Stop a running claude job.
--- @param job_id number
function M.stop(job_id)
	pcall(vim.fn.jobstop, job_id)
end

return M
