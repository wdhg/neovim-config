vim.g.mapleader = ' '

-- display
vim.opt.termguicolors = true
vim.scriptencoding = 'UTF-8'
vim.opt.encoding = 'UTF-8'
vim.opt.fileencoding = 'UTF-8'

-- gui
vim.opt.number = true
vim.opt.cursorline = true
vim.opt.list = true
vim.opt.colorcolumn = '80'
vim.opt.inccommand = 'nosplit'
vim.opt.conceallevel = 0
vim.opt.signcolumn = 'yes'

-- indenting
vim.opt.cindent = true
vim.opt.expandtab = false
vim.opt.smarttab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 0
vim.opt.shiftwidth = 0

-- functionality
vim.opt.mouse = 'a'
vim.opt.exrc = true
vim.opt.secure = true

-- formatoptions
local formatoptions = vim.api.nvim_get_option('formatoptions')
formatoptions = formatoptions:gsub('o', '')
vim.api.nvim_set_option('formatoptions', formatoptions)

-- languages
vim.cmd('au BufRead,BufNewFile *.h set filetype=c')
