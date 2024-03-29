local status, nvim_lsp = pcall(require, 'lspconfig')
if not status then return end

-- default on_attach, TODO check if I actually need this
local on_attach = function(client, bufnr)
  vim.cmd('autocmd BufWritePre <buffer> lua vim.lsp.buf.format()')
end

-- generic language server for filling in the gaps of other LSPs
nvim_lsp.efm.setup {
  on_attach = on_attach,
  filetypes = {
    'python',
  },
  init_options = {documentFormatting = true},
}

-- c
nvim_lsp.clangd.setup {
  on_attach = on_attach,
}

-- python
nvim_lsp.pyright.setup {
   on_attach = on_attach,
   filetypes = { 'python' },
   cmd = { 'pyright-langserver', '--stdio' },
 }

-- typescript
nvim_lsp.tsserver.setup {
  on_attach = on_attach,
}

-- go
nvim_lsp.gopls.setup {
  on_attach = on_attach,
  filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
  cmd = { 'gopls' },
}

-- astro
nvim_lsp.astro.setup {
  on_attach = on_attach,
  filetypes = { 'astro' },
  cmd = { 'npx', 'astro-ls', '--stdio' },
}

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
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
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
