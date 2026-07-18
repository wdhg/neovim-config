-- providers
-- local function try_get_uv_python3()
-- 	if vim.fn.executable('uv') == 0 then
-- 		return nil
-- 	end
-- 
-- 	local uv_python = vim.fn.system('uv python find 2>/dev/null'):gsub('\n', '')
-- 	if vim.v.shell_error == 0 and uv_python ~= '' then
-- 		return uv_python
-- 	end
-- 
-- 	return nil
-- end
-- 
-- local function try_get_pyenv_python3()
-- 	if vim.fn.executable('pyenv') == 0 then
-- 		return nil
-- 	end
-- 
-- 	local pyenv_python = vim.fn.system('pyenv which python 2>/dev/null'):gsub('\n', '')
-- 	if vim.v.shell_error == 0 and pyenv_python ~= '' then
-- 		return pyenv_python
-- 	end
-- 
-- 	return nil
-- end
-- 
-- local function get_python3_host()
-- 	return try_get_uv_python3()
-- 		or try_get_pyenv_python3()
-- 		or vim.fn.exepath('python3')
-- end

-- If uv is installed, we can setup and use the virtual environment
if vim.fn.executable("uv") ~= 0 then
	local config_path = vim.fn.stdpath('config')
	local venv_path   = config_path.. '/.venv'
	local code        = os.execute('[ -d ' .. venv_path .. ' ]')
	if code ~= 0 then
		print("Creating neovim virtual environment...")
		os.execute("cd " .. config_path.. " && uv venv && uv sync")
		print("Done")
	end
	vim.g.python3_host_prog = venv_path .. "/bin/python"
else
	print("Warning: Using system python")
	-- Fallback on system python
	vim.g.python3_host_prog = vim.fn.exepath('python3')
end

