local status, telekasten = pcall(require, 'telekasten')
if not status then return end

local telekasten_home = vim.fn.expand('~/zettelkasten')

telekasten.setup {
  home = telekasten_home,
}

-- Launch panel if nothing is typed after <leader>z
vim.keymap.set('n', '<leader>z', '<cmd>Telekasten panel<CR>')

-- Most used functions
vim.keymap.set('n', '<leader>zf', '<cmd>Telekasten find_notes<CR>')
vim.keymap.set('n', '<leader>zg', '<cmd>Telekasten search_notes<CR>')
vim.keymap.set('n', '<leader>zd', '<cmd>Telekasten goto_today<CR>')
vim.keymap.set('n', '<leader>zz', '<cmd>Telekasten follow_link<CR>')
vim.keymap.set('n', '<leader>zn', '<cmd>Telekasten new_note<CR>')
vim.keymap.set('n', '<leader>zc', '<cmd>Telekasten show_calendar<CR>')
vim.keymap.set('n', '<leader>zb', '<cmd>Telekasten show_backlinks<CR>')
vim.keymap.set('n', '<leader>zI', '<cmd>Telekasten insert_img_link<CR>')

-- Call insert link automatically when we start typing a link
function tk_insert_link()
  local file_path = vim.fn.expand('%')
  if file_path:find('^' .. telekasten_home) ~= nil then
    local bufnr = vim.api.nvim_get_current_buf()
    vim.keymap.set('i', '[[', '<cmd>Telekasten insert_link<CR>', { silent = true, buffer = bufnr } )
  end
end

vim.cmd('autocmd BufEnter * lua tk_insert_link()')
