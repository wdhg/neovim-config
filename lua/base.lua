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
vim.opt.listchars   = 'tab:▏ ,trail:▸'
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
-- TODO check python is available via asdf before setting these
vim.g.python_host_prog  = vim.fn.system('command -v python')
vim.g.python3_host_prog = vim.fn.system('command -v python3')
vim.g.node_host_prog    = vim.fn.system('command -v neovim-node-host')

-- updatetime
vim.api.nvim_set_option('updatetime', 300)
