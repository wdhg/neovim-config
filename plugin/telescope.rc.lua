local status, telescope = pcall(require, 'telescope')
if not status then return end

local status, builtin = pcall(require, 'telescope.builtin')
if not status then return end

vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})

telescope.setup {
  extensions = {
    file_browser = {
      -- theme = 'ivy',
      -- disables netrw and use telescope-file-browser in its place
      hijack_netrw = true,
      mappings = {
        ['i'] = {
        },
        ['n'] = {
        },
      },
    },
  },
}

telescope.load_extension('file_browser')
