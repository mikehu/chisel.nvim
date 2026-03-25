local config = require("chisel.config")
config.setup({})

local claude = require("chisel.backend.claude")

describe("chisel.backend.claude", function()
	describe("_build_cmd", function()
		it("builds command for file mode", function()
			local ctx = {
				mode = "file",
				file_path = "/tmp/test.lua",
				filetype = "lua",
				start_line = 10,
			}
			local cmd = claude._build_cmd("fix the bug", ctx)

			assert.are.equal("claude", cmd[1])
			assert.are.equal("-p", cmd[2])
			assert.are.equal("fix the bug", cmd[3])

			-- Should contain --tools Read,Edit
			local has_tools = false
			for i, arg in ipairs(cmd) do
				if arg == "--tools" and cmd[i + 1] == "Read,Edit" then
					has_tools = true
				end
			end
			assert.is_true(has_tools, "expected --tools Read,Edit in command")
		end)

		it("builds command for replace mode with selection", function()
			local ctx = {
				mode = "replace",
				file_path = "/tmp/test.lua",
				filetype = "lua",
				start_line = 5,
				end_line = 10,
				text = "local x = 1\nlocal y = 2",
			}
			local cmd = claude._build_cmd("rename variables", ctx)

			-- Should have --append-system-prompt with selection info
			local has_system = false
			for i, arg in ipairs(cmd) do
				if arg == "--append-system-prompt" then
					local prompt = cmd[i + 1]
					has_system = prompt:find("lines 5%-10") ~= nil
				end
			end
			assert.is_true(has_system, "expected system prompt to reference line range")
		end)

		it("includes --dangerously-skip-permissions", function()
			local ctx = {
				mode = "file",
				file_path = "/tmp/test.lua",
				filetype = "lua",
				start_line = 1,
			}
			local cmd = claude._build_cmd("test", ctx)

			local found = false
			for _, arg in ipairs(cmd) do
				if arg == "--dangerously-skip-permissions" then
					found = true
				end
			end
			assert.is_true(found, "expected --dangerously-skip-permissions flag")
		end)

		it("includes all configured args", function()
			local ctx = {
				mode = "file",
				file_path = "/tmp/test.lua",
				filetype = "lua",
				start_line = 1,
			}
			local cmd = claude._build_cmd("test", ctx)

			local cmd_str = table.concat(cmd, " ")
			assert.is_truthy(cmd_str:find("--verbose"))
			assert.is_truthy(cmd_str:find("stream%-json"))
			assert.is_truthy(cmd_str:find("--no%-session%-persistence"))
		end)
	end)

	describe("_process_line", function()
		local state, results

		before_each(function()
			state = { text = "", thinking = "", done = false }
			results = { text = {}, thinking = {}, done = {}, error = {} }
		end)

		local function make_callbacks()
			return {
				on_text = function(t)
					table.insert(results.text, t)
				end,
				on_thinking = function(t)
					table.insert(results.thinking, t)
				end,
				on_done = function(t)
					table.insert(results.done, t)
				end,
				on_error = function(msg)
					table.insert(results.error, msg)
				end,
			}
		end

		it("ignores empty lines", function()
			claude._process_line("", make_callbacks(), state)
			assert.are.equal(0, #results.text)
			assert.are.equal(0, #results.done)
		end)

		it("ignores invalid JSON", function()
			claude._process_line("not json at all", make_callbacks(), state)
			assert.are.equal(0, #results.text)
		end)

		it("accumulates text_delta events", function()
			local cb = make_callbacks()
			local event1 = vim.json.encode({
				type = "content_block_delta",
				delta = { type = "text_delta", text = "hello " },
			})
			local event2 = vim.json.encode({
				type = "content_block_delta",
				delta = { type = "text_delta", text = "world" },
			})

			claude._process_line(event1, cb, state)
			assert.are.equal("hello ", state.text)

			claude._process_line(event2, cb, state)
			assert.are.equal("hello world", state.text)
			assert.are.equal(2, #results.text)
		end)

		it("accumulates thinking_delta events", function()
			local cb = make_callbacks()
			local event = vim.json.encode({
				type = "content_block_delta",
				delta = { type = "thinking_delta", thinking = "let me think..." },
			})

			claude._process_line(event, cb, state)
			assert.are.equal("let me think...", state.thinking)
			assert.are.equal(1, #results.thinking)
		end)

		it("fires on_done for result events", function()
			local cb = make_callbacks()
			state.text = "accumulated text"

			local event = vim.json.encode({ type = "result" })
			claude._process_line(event, cb, state)

			assert.is_true(state.done)
			assert.are.equal(1, #results.done)
			assert.are.equal("accumulated text", results.done[1])
		end)

		it("does not fire on_done twice for duplicate result events", function()
			local cb = make_callbacks()
			local event = vim.json.encode({ type = "result" })

			claude._process_line(event, cb, state)
			claude._process_line(event, cb, state)

			assert.are.equal(1, #results.done)
		end)

		it("unwraps stream_event wrapper", function()
			local cb = make_callbacks()
			local event = vim.json.encode({
				type = "stream_event",
				event = {
					type = "content_block_delta",
					delta = { type = "text_delta", text = "wrapped" },
				},
			})

			claude._process_line(event, cb, state)
			assert.are.equal("wrapped", state.text)
		end)

		it("handles assistant message with content blocks", function()
			local cb = make_callbacks()
			local event = vim.json.encode({
				type = "assistant",
				message = {
					content = {
						{ type = "text", text = "full response" },
					},
				},
			})

			claude._process_line(event, cb, state)
			assert.are.equal("full response", state.text)
		end)

		it("strips carriage returns from lines", function()
			local cb = make_callbacks()
			local event = vim.json.encode({
				type = "content_block_delta",
				delta = { type = "text_delta", text = "clean" },
			})
			-- Simulate \r in the line
			local line = event .. "\r"

			claude._process_line(line, cb, state)
			assert.are.equal("clean", state.text)
		end)
	end)
end)
