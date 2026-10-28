vim.g.mapleader = ' '

-- display
vim.opt.termguicolors = true
vim.scriptencoding    = 'UTF-8'
vim.opt.encoding      = 'UTF-8'
-- NB: global scope — vim.opt.fileencoding writes the CURRENT buffer and
-- raises E21 when reloading with the cursor in a non-modifiable buffer (e.g.
-- a dap float). The default is UTF-8 anyway, so global-only is equivalent.
vim.opt_global.fileencoding = 'UTF-8'

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
vim.api.nvim_create_augroup('BaseAutocmds', { clear = true })
vim.api.nvim_create_autocmd('FileType', { group = 'BaseAutocmds', command = 'set formatoptions-=cro' })

-- languages
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
	group = 'BaseAutocmds',
	pattern = '*.h',
	command = 'set filetype=c',
})

vim.g.node_host_prog    = vim.fn.system('command -v neovim-node-host')

-- updatetime
vim.api.nvim_set_option('updatetime', 300)
