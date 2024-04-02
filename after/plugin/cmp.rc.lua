local status, cmp = pcall(require, 'cmp')
if not status then return end

local lspkind = require('lspkind')

cmp.setup({
	snippet = {
		expand = function(args)
			vim.fn['vsnip#anonymous'](args.body)
		end,
	},
	mapping = cmp.mapping.preset.insert({
		['<C-p>'] = cmp.mapping.select_prev_item(),
		['<C-n>'] = cmp.mapping.select_next_item(),
		-- Add tab support
		['<S-Tab>'] = cmp.mapping.select_prev_item(),
		['<Tab>'] = cmp.mapping.select_next_item(),
		['<C-S-f>'] = cmp.mapping.scroll_docs(-4),
		['<C-f>'] = cmp.mapping.scroll_docs(4),
		['<C-Space>'] = cmp.mapping.complete(),
		['<C-e>'] = cmp.mapping.close(),
		['<CR>'] = cmp.mapping.confirm({
			behavior = cmp.ConfirmBehavior.Insert,
			select = true,
		})
	}),
	sources = cmp.config.sources({
		{ name = 'path' },															-- file paths
		{ name = 'nvim_lsp', keyword_length = 3 },			-- from language server
		{ name = 'nvim_lsp_signature_help'},						-- display function signatures with current parameter emphasized
		{ name = 'nvim_lua', keyword_length = 2},				-- complete neovim's Lua runtime API such vim.lsp.*
		{ name = 'buffer', keyword_length = 2 },				-- source current buffer
		{ name = 'vsnip', keyword_length = 2 },					-- nvim-cmp source for vim-vsnip 
		{ name = 'calc'},																-- source for math calculation
	}),
	window = {
			completion = cmp.config.window.bordered(),
			documentation = cmp.config.window.bordered(),
	},
	formatting = {
		format = lspkind.cmp_format({ with_text = false, maxwidth = 50 }),
		-- fields = {'menu', 'abbr', 'kind'},
	},
})

vim.opt.completeopt = {'menuone', 'noselect', 'noinsert'}
vim.opt.shortmess = vim.opt.shortmess + { c = true}
vim.cmd('highlight! default link CmpItemKind CmpItemMenuDefault')

-- ' Use <Tab> and <S-Tab> to navigate through popup menu
-- inoremap <expr> <Tab>	 pumvisible() ? '\<C-n>' : '\<Tab>'
-- inoremap <expr> <S-Tab> pumvisible() ? '\<C-p>' : '\<S-Tab>'
