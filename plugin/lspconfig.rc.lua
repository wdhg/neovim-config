local status, nvim_lsp = pcall(require, 'lspconfig')

if (not status) then
  return
end

local protocol = require('vim.lsp.protocol')

local on_attach = function(client, bufnr)
  vim.cmd [[autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_sync()]]
end

-- set up completion using nvim_cmp with LSP source
local capabilities = require('cmp_nvim_lsp').update_capabilities(
  vim.lsp.protocol.make_client_capabilities()
)

-- generic language server for filling in the gaps of other LSPs
nvim_lsp.efm.setup {
  on_attach = on_attach,
  filetypes = {
    'python',
    'javascript',
    'javascriptreact',
    'typescript',
    'typescriptreact',
    'rust',
  },
  init_options = {documentFormatting = true},
}

-- python
nvim_lsp.pyright.setup {
   on_attach = on_attach,
   filetypes = { 'python'},
   cmd = { 'pyright-langserver', '--stdio' },
   capabilities = capabilities,
 }

-- typescript
nvim_lsp.tsserver.setup {
  -- turn off formatting because it doesn't work
  on_attach = function(client)
    client.resolved_capabilities.document_formatting = false
    client.resolved_capabilities.document_range_formatting = false
  end,
}

-- astro
nvim_lsp.astro.setup {
  on_attach = on_attach,
  filetypes = { 'astro' },
  cmd = { 'astro-ls', '--stdio' },
  capabilities = capabilities,
}

-- markdown / latex
nvim_lsp.grammar_guard.setup {
  cmd = { 'ltex-ls' },
  settings = {
    ltex = {
      enabled = { "latex", "tex", "bib", "markdown" },
      language = "en",
      diagnosticSeverity = "information",
      setenceCacheSize = 2000,
      additionalRules = {
        enablePickyRules = true,
        motherTongue = "en",
      },
      trace = { server = "verbose" },
      dictionary = {},
      disabledRules = {},
      hiddenFalsePositives = {},
    },
  },
}

