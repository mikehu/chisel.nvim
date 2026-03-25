-- Minimal init for plenary test runner.
-- Adds the plugin and plenary to the runtimepath.

-- Resolve plugin root from this file's location (works in subprocesses too)
local source = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(source, ":p:h:h")
vim.opt.rtp:prepend(root)

-- Also add the Lua module path so require("chisel.*") resolves here first
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

-- Add plenary from lazy's install location
local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 1 then
	vim.opt.rtp:prepend(plenary_path)
end

vim.cmd("runtime plugin/plenary.vim")
