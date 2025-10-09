-- GitHub Copilot configuration
vim.g.copilot_no_tab_map = true
vim.keymap.set('i', '<C-j>', 'copilot#Accept("")', {
  expr = true,
  replace_keycodes = false
})
