-- Neovim's own python (provider plugins, e.g. ollama) is separate from
-- project pythons, which are handled by the LSP commands in lspconfig.rc.lua

-- If uv is installed, we can setup and use the virtual environment
if vim.fn.executable("uv") ~= 0 then
	local config_path = vim.fn.stdpath('config')
	local venv_path   = config_path.. '/.venv'
	if vim.fn.isdirectory(venv_path) == 0 then
		print("Creating neovim virtual environment...")
		vim.fn.system({ 'uv', 'venv', '--directory', config_path })
		if vim.v.shell_error == 0 then
			vim.fn.system({ 'uv', 'sync', '--directory', config_path })
		end
		print("Done")
	end
	if vim.fn.filereadable(venv_path .. '/bin/python') == 1 then
		vim.g.python3_host_prog = venv_path .. '/bin/python'
	else
		print("Warning: neovim venv unavailable, using system python")
		vim.g.python3_host_prog = vim.fn.exepath('python3')
	end
elseif vim.fn.exepath('python3') ~= '' then
	print("Warning: Using system python")
	vim.g.python3_host_prog = vim.fn.exepath('python3')
else
	print("Warning: No python3 found, python provider disabled")
end
