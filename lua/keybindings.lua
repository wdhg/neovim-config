local keymap = vim.keymap

keymap.set('n', 'r', ':redo<cr>')
keymap.set({'n', 'i'}, '<f1>', '<nop>')
keymap.set('n', '<tab>', ':Telescope file_browser<cr>', { noremap = true, silent = true })
