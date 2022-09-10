local status, packer = pcall(require, 'packer')

if (not status) then
  print('Packer is not installed')
  return
end

vim.cmd [[packadd packer.nvim]]

packer.startup(function(use)
  -- General
  use 'wbthomason/packer.nvim'                     -- package manager
  use 'wdhg/dragon-energy'                         -- colorscheme
  use 'onsails/lspkind-nvim'                       -- vscode-like pictograms
  use 'hrsh7th/cmp-buffer'                         -- nvim-cmp source for buffer words
  use 'hrsh7th/cmp-nvim-lsp'                       -- nvim-cmp source for neovim's built-in LSP
  use 'hrsh7th/nvim-cmp'                           -- code completion
  use 'neovim/nvim-lspconfig'                      -- configurations for nvim lsp
  use 'L3MON4D3/LuaSnip'                           -- snippet engine
  use 'nvim-lua/plenary.nvim'                      -- common utilities, used by telescope
  use 'mfussenegger/nvim-dap'                      -- debug adapter protocol
  use 'nvim-telescope/telescope.nvim'              -- fuzzy finder
  use 'nvim-telescope/telescope-file-browser.nvim' -- file explorer
  use 'vim-airline/vim-airline'                    -- airline tabline
  -- Text
  use 'brymer-meneses/grammar-guard.nvim'          -- grammar check
  -- JavaScript / TypeScript
  use 'yuezk/vim-js'                               -- javascript
  use 'MaxMEllon/vim-jsx-pretty'                   -- jsx
  use 'wuelnerdotexe/vim-astro'                    -- astro
  -- Rust
  use 'simrat39/rust-tools.nvim'                   -- rust
end)
