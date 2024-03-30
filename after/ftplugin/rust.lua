local bufnr = vim.api.nvim_get_current_buf()

vim.keymap.set(
  'n',
  '<leader>a',
  function()
    vim.cmd.RustLsp('codeAction') -- supports rust-analyzer's grouping
    -- or vim.lsp.buf.codeAction() if you don't want grouping.
  end,
  { silent = true, buffer = bufnr }
)

vim.keymap.set(
  'n',
  '<C-b>',
  ':!tmux send-keys -t 2 "cargo run" Enter<cr><cr>',
  { silent = true, buffer = bufnr }
)
