-- default on_attach, TODO check if I actually need this
local on_attach = function(client, bufnr)
	vim.cmd('autocmd BufWritePre <buffer> lua vim.lsp.buf.format()')
end

-- c
vim.lsp.config('clangd', {
	cmd = {
		"clangd",
		"--background-index",
		"--completion-style=detailed",
		"--header-insertion=iwyu",
		"--header-insertion-decorators",
	},
})
vim.lsp.enable('clangd')

-- python
local function get_ruff_cmd()
	-- Check if uv is being used in the project
	if vim.fn.filereadable('pyproject.toml') == 1 or vim.fn.filereadable('uv.lock') == 1 then
		if vim.fn.executable('uv') == 1 then
			return { 'uv', 'run', 'ruff', 'server', '--preview' }
		end
	end
	
	-- Check if .python-version exists (pyenv)
	if vim.fn.filereadable('.python-version') == 1 then
		local pyenv_root = vim.fn.system('pyenv root 2>/dev/null'):gsub('\n', '')
		if vim.v.shell_error == 0 and pyenv_root ~= '' then
			local python_version = vim.fn.system('pyenv version-name 2>/dev/null'):gsub('\n', '')
			if vim.v.shell_error == 0 and python_version ~= '' then
				local pyenv_ruff = pyenv_root .. '/versions/' .. python_version .. '/bin/ruff'
				if vim.fn.executable(pyenv_ruff) == 1 then
					return { pyenv_ruff, 'server', '--preview' }
				end
			end
		end
	end
	
	-- Fallback to system ruff
	if vim.fn.executable('ruff') == 1 then
		return { 'ruff', 'server', '--preview' }
	end
	
	return nil
end

local function get_pyright_cmd()
	local uv_tool = vim.fn.system('uv tool dir 2>/dev/null'):gsub('\n', '')
	if vim.v.shell_error == 0 and uv_tool ~= '' then
		local uv_pyright = uv_tool .. '/pyright/bin/pyright-langserver'
		if vim.fn.executable(uv_pyright) == 1 then
			return { uv_pyright, '--stdio' }
		end
	end
	return { 'pyright-langserver', '--stdio' }
end

-- ruff for linting and formatting
local ruff_cmd = get_ruff_cmd()
if ruff_cmd then
	vim.lsp.config('ruff', {
		cmd = ruff_cmd,
		init_options = {
			settings = {
				args = {},
			}
		}
	})
	vim.lsp.enable('ruff')
end

-- pyright for semantic features (type checking, go-to-def, rename, etc)
vim.lsp.config('pyright', {
	cmd = get_pyright_cmd(),
	settings = {
		pyright = {
			-- Disable pyright's formatting and import organizing since ruff handles this
			disableOrganizeImports = true,
		},
		python = {
			analysis = {
				-- Disable pyright's linting since ruff handles this
				typeCheckingMode = "basic",
			}
		}
	}
})
vim.lsp.enable('pyright')

-- typescript
-- nvim_lsp.tsserver.setup {
-- 	on_attach = on_attach,
-- }

-- go
vim.lsp.config('gopls', {
	on_attach = on_attach,
	filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
	cmd = { 'gopls' },
})
vim.lsp.enable('gopls')

-- astro
vim.lsp.config('astro', {
	on_attach = on_attach,
	filetypes = { 'astro' },
	cmd = { 'npx', 'astro-ls', '--stdio' },
})
vim.lsp.enable('astro')

-- tex
vim.lsp.config('texlab', {
	auxDirectory = ".",
	bibtexFormatter = "texlab",
	build = {
		args = { "-pdf", "-interaction=nonstopmode", "-synctex=1", "%f" },
		executable = "latexmk",
		forwardSearchAfter = false,
		onSave = false
	},
	chktex = {
		onEdit = false,
		onOpenAndSave = false
	},
	diagnosticsDelay = 300,
	formatterLineLength = 80,
	forwardSearch = {
		args = {}
	},
	latexFormatter = "latexindent",
	latexindent = {
		modifyLineBreaks = false
	}
})
vim.lsp.enable('texlab')

vim.lsp.config('cssls', {})
vim.lsp.enable('cssls')

vim.lsp.config('ltex', {
	settings = {
		ltex = {
			language = "en-GB",
			additionalRules = {
				languageModel = "$HOME/.languagetool/n-gram/",
			},
		},
	},
})
vim.lsp.enable('ltex')

-- Global mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
vim.keymap.set('n', '<space>e', vim.diagnostic.open_float)
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist)

-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
vim.api.nvim_create_autocmd('LspAttach', {
	group = vim.api.nvim_create_augroup('UserLspConfig', {}),
	callback = function(ev)
		-- Enable completion triggered by <c-x><c-o>
		vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

		-- Buffer local mappings.
		-- See `:help vim.lsp.*` for documentation on any of the below functions
		local opts = { buffer = ev.buf }
		vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
		vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
		vim.keymap.set('n', 'K', function() vim.lsp.buf.hover({ border = 'rounded' }) end, opts)
		vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
		vim.keymap.set('n', '<C-k>', function() vim.lsp.buf.signature_help({ border = 'rounded' }) end, opts)
		vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
		vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
		vim.keymap.set('n', '<space>wl', function()
			print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
		end, opts)
		vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
		vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
		vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
		vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
		vim.keymap.set('n', '<space>f', function()
			vim.lsp.buf.format { async = true }
		end, opts)
	end,
})
