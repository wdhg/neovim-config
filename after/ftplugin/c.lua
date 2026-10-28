vim.keymap.set('n', '<leader>e', require('macro_expand').expand, {
	buffer = true,
	silent = true,
	desc = 'Expand C macro under cursor',
})
