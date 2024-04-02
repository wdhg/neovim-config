vim.keymap.set(
	'n',
	'<leader>a',
	function()
		vim.lsp.buf.codeAction()
	end,
	{ silent = true, buffer = bufnr }
)

vim.keymap.set(
	'n',
	'<C-b>',
	function()
		local filepath = vim.api.nvim_buf_get_name(0)
		local filename = vim.fn.fnamemodify(filepath, ":t")
		local out = os.execute("tmux send-keys -t 2 'python " .. filename .. "' Enter")
	end,
	{ silent = true, buffer = bufnr }
)
