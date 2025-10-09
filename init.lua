IS_WORK_DEVICE = vim.fn.filereadable(vim.fn.stdpath('config') .. '/.work') == 1

require('base')
require('plugins')
require('syntax')
require('keybindings')

function load_local_config()
	package.loaded['local']  = nil -- Unload module if it is already loade
	local cwd                = vim.fn.getcwd()
	local config_path        = cwd .. '/.nvim'
	local code = os.execute('[ -d ' .. config_path .. ' ]')
	if code ~= 0 then
		return
	end
	package.path = package.path .. ';' .. config_path .. '/?.lua'
	require('local') -- .nvim/local.lua
	print(config_path .. ' loaded')
end

load_local_config()
