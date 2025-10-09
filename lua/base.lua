vim.g.mapleader = ' '

-- display
vim.opt.termguicolors = true
vim.scriptencoding    = 'UTF-8'
vim.opt.encoding      = 'UTF-8'
vim.opt.fileencoding  = 'UTF-8'

-- gui
vim.opt.number       = true
vim.opt.cursorline   = true
vim.opt.list         = true
vim.opt.inccommand   = 'nosplit'
vim.opt.conceallevel = 0
vim.opt.signcolumn   = 'yes'
vim.diagnostic.config {
	virtual_text     = true,
	signs            = true,
	update_in_insert = true,
	underline        = true,
	severity_sort    = true,
	float            = {
		border = 'rounded',
		source = 'always',
		header = '',
		prefix = '',
	},
}

-- indenting
vim.opt.cindent     = true
vim.opt.expandtab   = false
vim.opt.smarttab    = true
vim.opt.tabstop     = 8
vim.opt.softtabstop = 0
vim.opt.shiftwidth  = 8
vim.opt.list        = true
vim.opt.listchars   = 'tab:│ ,trail:▸'
vim.opt.breakindent = true
vim.opt.linebreak   = true

-- functionality
vim.opt.mouse      = 'a'
vim.opt.exrc       = true
vim.opt.secure     = true
vim.opt.foldmethod = 'marker'

-- formatoptions
vim.cmd('au FileType * set formatoptions-=cro')

-- languages
vim.cmd('au BufRead,BufNewFile *.h set filetype=c')

-- providers
local function try_get_uv_python3()
	if vim.fn.executable('uv') == 0 then
		return nil
	end

	local uv_python = vim.fn.system('uv python find 2>/dev/null'):gsub('\n', '')
	if vim.v.shell_error == 0 and uv_python ~= '' then
		return uv_python
	end

	return nil
end

local function try_get_pyenv_python3()
	if vim.fn.executable('pyenv') == 0 then
		return nil
	end

	local pyenv_python = vim.fn.system('pyenv which python 2>/dev/null'):gsub('\n', '')
	if vim.v.shell_error == 0 and pyenv_python ~= '' then
		return pyenv_python
	end

	return nil
end

local function get_python3_host()
	return try_get_uv_python3()
		or try_get_pyenv_python3()
		or vim.fn.exepath('python3')
end

vim.g.python3_host_prog = get_python3_host()
vim.g.node_host_prog    = vim.fn.system('command -v neovim-node-host')

-- updatetime
vim.api.nvim_set_option('updatetime', 300)
