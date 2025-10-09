IS_WORK_DEVICE = vim.fn.filereadable(vim.fn.stdpath('config')) .. '/.work' == 1

require('base')
require('plugins')
require('syntax')
require('keybindings')
