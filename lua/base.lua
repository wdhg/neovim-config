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
vim.opt.colorcolumn = '100'
vim.opt.inccommand = 'nosplit'
vim.opt.conceallevel = 0
vim.opt.signcolumn = 'yes'
vim.diagnostic.config {
  virtual_text = true,
  signs = true,
  update_in_insert = true,
  underline = true,
  severity_sort = true,
  float = {
      border = 'rounded',
      source = 'always',
      header = '',
      prefix = '',
  },
}

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

-- providers
-- TODO check python is available via asdf before setting these
vim.g.python_host_prog = '~/.asdf/installs/python/2.7.18/bin/python'
vim.g.python3_host_prog = '~/.asdf/installs/python/3.12.2/bin/python'

-- updatetime
vim.api.nvim_set_option('updatetime', 300)
