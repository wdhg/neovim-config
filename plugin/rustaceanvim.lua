vim.g.rustaceanvim = {
	-- Plugin configuration
	tools = {
	},
	-- LSP configuration
	server = {
		on_attach = function(client, bufnr)
			vim.cmd('autocmd BufWritePre <buffer> lua vim.lsp.buf.format()')
		end,
		default_settings = {
			-- rust-analyzer language server configuration
			['rust-analyzer'] = {
			},
		},
	},
	-- DAP configuration
	dap = {
	},
}
