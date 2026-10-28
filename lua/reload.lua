-- :ReloadConfig — re-execute the neovim config in place.
--
-- Order mirrors a normal startup: the lua/ modules first, then plugin/ and
-- after/plugin/ sources, then the per-project .nvim config. Files must be
-- idempotent for this to work (autocmds in named augroups with clear=true,
-- keymaps are overwritten anyway).
--
-- plugins.lua is deliberately skipped: re-running packer.startup mid-session
-- isn't supported, so after changing the plugin list run :PackerSync instead.

-- every module under lua/, discovered at reload time — so new modules (e.g.
-- lua/termrun.lua, lua/dapinspect.lua) are picked up without edits here.
-- plugins.lua is intentionally absent: re-running packer.startup mid-session
-- isn't supported, so after changing the plugin list run :PackerSync instead.
local function modules_to_reload()
	local mods = {}
	for _, file in ipairs(vim.fn.glob(vim.fn.stdpath('config') .. '/lua/*.lua', false, true)) do
		local mod = vim.fn.fnamemodify(file, ':t:r')
		-- packer.startup can't run mid-session (see the header above)
		if mod ~= 'plugins' then
			mods[#mods + 1] = mod
		end
	end
	return mods
end

local function nvim_err_writeln_all(errors)
	vim.notify(('ReloadConfig: %d error(s), see :messages'):format(#errors), vim.log.levels.ERROR)
	for _, e in ipairs(errors) do
		-- vim.fn.string() produces a properly escaped vimscript literal
		-- (extra parens so gsub's second return value is discarded)
		vim.cmd('echomsg ' .. vim.fn.string((e:gsub('\n', ' '))))
	end
end

local function load_local_config()
	local config_path = vim.fn.getcwd() .. '/.nvim'
	if vim.fn.isdirectory(config_path) == 0 then
		return
	end
	if not package.path:find(config_path, 1, true) then
		package.path = package.path .. ';' .. config_path .. '/?.lua'
	end
	package.loaded['local'] = nil
	pcall(require, 'local') -- .nvim/local.lua
end

local function run_reload_steps()
	local errors = {}
	local function try(what, fn)
		local ok, err = pcall(fn)
		if not ok then
			errors[#errors + 1] = what .. ': ' .. tostring(err)
		end
	end

	local modules = modules_to_reload()

	-- 1. Forget the loaded modules so require() re-executes them
	for _, mod in ipairs(modules) do
		package.loaded[mod] = nil
	end

	-- 2. Re-execute them (same order as init.lua, minus plugins)
	for _, mod in ipairs(modules) do
		try('lua/' .. mod .. '.lua', function() require(mod) end)
	end

	-- 3. Re-source plugin configs (packer_compiled.lua excluded — see header).
	-- Each file independently: a broken file shouldn't abort the rest.
	local config_dir = vim.fn.stdpath('config')
	local patterns = { 'plugin/*.lua', 'after/plugin/*.lua' }
	for _, pattern in ipairs(patterns) do
		for _, file in ipairs(vim.fn.glob(config_dir .. '/' .. pattern, false, true)) do
			if vim.fs.basename(file) ~= 'packer_compiled.lua' then
				try(vim.fn.fnamemodify(file, ':~:.'), function()
					vim.cmd('source ' .. vim.fn.fnameescape(file))
				end)
			end
		end
	end

	-- 4. Re-apply the per-project config
	try('project .nvim config', load_local_config)

	-- 5. Plugin one-shot events won't re-fire after a reload; nudge the ones
	-- that matter so cosmetic setup re-runs
	pcall(vim.cmd, 'doautocmd User AirlineAfterInit')
	pcall(vim.cmd, 'AirlineRefresh')

	-- 6. Re-apply buffer-local config (ftplugin, after/ftplugin) to buffers
	-- that are already open. Per-buffer with pcall: a non-modifiable buffer
	-- (dap console, inspector floats) must not abort the rest.
	try('ftplugin refresh', function()
		for _, info in ipairs(vim.fn.getbufinfo({ bufloaded = 1 })) do
			pcall(vim.api.nvim_exec_autocmds, 'FileType', { buffer = info.bufnr })
		end
	end)

	if #errors > 0 then
		nvim_err_writeln_all(errors)
	else
		vim.notify('config reloaded')
	end
end

local function reload()
	-- Some buffer-local option settings (fileencoding & co) raise E21 when the
	-- current buffer is non-modifiable — e.g. when the cursor sits in a dap
	-- console or inspector float. Run the whole reload from a throwaway
	-- modifiable buffer context, then restore focus.
	local origin_win = vim.api.nvim_get_current_win()
	local scratch = vim.api.nvim_create_buf(false, true)
	local scratch_win = vim.api.nvim_open_win(scratch, false, {
		relative = 'editor',
		width = 1,
		height = 1,
		row = vim.o.lines - 1,
		col = vim.o.columns - 1,
		style = 'minimal',
		noautocmd = true,
	})
	vim.api.nvim_set_current_win(scratch_win)

	local ok, err = pcall(run_reload_steps)

	vim.api.nvim_win_close(scratch_win, true)
	pcall(vim.api.nvim_set_current_win, origin_win)
	if not ok then
		vim.notify('ReloadConfig crashed: ' .. tostring(err), vim.log.levels.ERROR)
	end
end

vim.api.nvim_create_user_command('ReloadConfig', reload, {
	desc = 'Reload the neovim config in place',
})

return { reload = reload }
