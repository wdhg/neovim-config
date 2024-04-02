local bufnr = vim.api.nvim_get_current_buf()

vim.keymap.set(
	'n',
	'<C-b>',
	':!tmux send-keys -t 2 "cargo run" Enter<cr><cr>',
	{ silent = true, buffer = bufnr }
)
