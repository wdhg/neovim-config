-- default on_attach, TODO check if I actually need this
local on_attach = function(client, bufnr)
	vim.cmd('autocmd BufWritePre <buffer> lua vim.lsp.buf.format()')
end

-- c
-- vim.lsp.config('clangd', {
-- 	cmd = {
-- 		"clangd",
-- 		"--background-index",
-- 		"--completion-style=detailed",
-- 		"--header-insertion=iwyu",
-- 		"--header-insertion-decorators",
-- 	},
-- })
-- vim.lsp.enable('clangd')

-- python
-- Commands are resolved per-buffer when a python file opens, relative to the
-- buffer's project root — not relative to nvim's launch directory. The
-- FileType autocmd below runs before the clients spawn, so each project gets
-- its own environment.
local function ruff_cmd_for(root)
	-- Project venv binary — works for any venv, uv-created or not
	if root and vim.fn.executable(root .. '/.venv/bin/ruff') == 1 then
		return { root .. '/.venv/bin/ruff', 'server', '--preview' }
	end

	-- Real uv project (has a lockfile): run inside its managed env
	if root and vim.fn.filereadable(root .. '/uv.lock') == 1 and vim.fn.executable('uv') == 1 then
		return { 'uv', 'run', '--directory', root, 'ruff', 'server', '--preview' }
	end

	-- pyenv-managed project
	if root and vim.fn.filereadable(root .. '/.python-version') == 1 and vim.fn.executable('pyenv') == 1 then
		local out = vim.system({ 'pyenv', 'which', 'ruff' }, { cwd = root }):wait()
		if out.code == 0 and out.stdout ~= '' and vim.fn.executable(out.stdout:gsub('%s+', '')) == 1 then
			return { out.stdout:gsub('%s+', ''), 'server', '--preview' }
		end
	end

	-- Fallback to system ruff
	if vim.fn.executable('ruff') == 1 then
		return { 'ruff', 'server', '--preview' }
	end

	return nil
end

local function pyright_config_for(root)
	local cmd
	if root and vim.fn.filereadable(root .. '/uv.lock') == 1 and vim.fn.executable('uv') == 1 then
		cmd = { 'uv', 'run', '--directory', root, 'pyright-langserver', '--stdio' }
	else
		cmd = { 'pyright-langserver', '--stdio' }
	end

	local config = { cmd = cmd }
	-- Point pyright at the project's interpreter so imports resolve without uv
	if root and vim.fn.filereadable(root .. '/.venv/bin/python') == 1 then
		config.settings = {
			python = {
				pythonPath = root .. '/.venv/bin/python',
			}
		}
	end
	return config
end

-- ruff for linting and formatting
vim.lsp.config('ruff', {
	init_options = {
		settings = {
			args = {},
		}
	}
})

-- pyright for semantic features (type checking, go-to-def, rename, etc)
vim.lsp.config('pyright', {
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

vim.api.nvim_create_autocmd('FileType', {
	group = vim.api.nvim_create_augroup('PythonLspCommands', {}),
	pattern = 'python',
	desc = 'Resolve python LSP commands from the buffer\'s project root',
	callback = function(ev)
		local root = vim.fs.root(ev.buf, { 'uv.lock', 'pyproject.toml', '.python-version', 'requirements.txt', 'setup.py', '.git' })

		local ruff_cmd = ruff_cmd_for(root)
		if ruff_cmd then
			vim.lsp.config('ruff', { cmd = ruff_cmd })
			vim.lsp.enable('ruff')
		else
			vim.lsp.enable('ruff', false)
		end

		vim.lsp.config('pyright', pyright_config_for(root))
	end,
})

vim.lsp.enable('ruff')
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
