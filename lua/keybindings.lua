local keymap = vim.keymap

keymap.set('n', 'Q', ':q!<cr>')
keymap.set('n', 'r', ':redo<cr>')
keymap.set('n', '<f1>', '<nop>')
keymap.set('i', '<f1>', '<nop>')
keymap.set('n', '<tab>', ':Telescope file_browser<cr>', { noremap = true, silent = true })
keymap.set('n', '<space>e', '<cmd>lua vim.diagnostic.open_float()<cr>', { noremap = true, silent = true })
