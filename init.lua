IS_WORK_DEVICE = vim.fn.filereadable(vim.fn.stdpath('config') .. '/.work') == 1

require('base')
require('python')
require('plugins')
require('syntax')
require('keybindings')
require('reload')

function load_local_config()
	package.loaded['local'] = nil -- Unload module if it is already loaded
	local cwd         = vim.fn.getcwd()
	local config_path = cwd .. '/.nvim'
	if vim.fn.isdirectory(config_path) == 0 then
		return
	end
	-- delimiter the entry so sibling dirs (e.g. '.nvim2') can't false-match
	if not (';' .. package.path .. ';'):find(';' .. config_path .. '/;', 1, true) then
		package.path = package.path .. ';' .. config_path .. '/?.lua'
	end
	-- the dir may also exist only to hold state (e.g. dap.json), so a missing
	-- local.lua is fine
	if pcall(require, 'local') then -- .nvim/local.lua
		print(config_path .. ' loaded')
	end
end

load_local_config()
