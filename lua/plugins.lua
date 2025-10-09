-- check if packer is downloaded, and if not, download it
-- returns true if packer was bootstrapped
local ensure_packer_is_installed = function()
	-- get path to where packer should be installed
	local install_path = vim.fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'

	-- check if packer is already installed
	if vim.fn.empty(install_path) == 0 then
		return false
	end

	-- install packer
	vim.fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
	-- source packer
	vim.cmd('packadd packer.nvim')
	return true
end

local packer_bootstrapped = ensure_packer_is_installed()
local status, packer = pcall(require, 'packer')

if not status then
	print('Packer is not installed')
	return
end

packer.startup(function(use)
	-- package management
	use 'wbthomason/packer.nvim' -- this keeps packer up to date

	-- LSP
	use 'williamboman/mason-lspconfig.nvim' -- bridge mason and lspconfig so they work together
	use 'neovim/nvim-lspconfig'             -- configurations for nvim lsp
	use 'onsails/lspkind-nvim'              -- vscode-like pictograms for lsp

	-- code completion
	use 'hrsh7th/nvim-cmp'
	use 'hrsh7th/cmp-nvim-lsp'                -- completion using LSP
	use 'hrsh7th/cmp-nvim-lua'                -- Neovim Lua API completion
	use 'hrsh7th/cmp-nvim-lsp-signature-help' -- type signatures preview
	use 'hrsh7th/cmp-path'                    -- completion for paths
	use 'hrsh7th/cmp-buffer'                  -- completion for words in buffer

	-- snippet engine (needed by nvim-cmp)
	use 'hrsh7th/cmp-vsnip'
	use 'hrsh7th/vim-vsnip'

	-- telescope
	use 'nvim-lua/plenary.nvim'                      -- common utilities, used by telescope
	use 'nvim-telescope/telescope.nvim'              -- fuzzy finder
	use 'nvim-telescope/telescope-file-browser.nvim' -- file explorer
	use 'aznhe21/actions-preview.nvim'               -- better LSP code action menu using telescope

	-- misc
	use 'nvim-treesitter/nvim-treesitter' -- treesitter
	use 'lewis6991/gitsigns.nvim'         -- git integration
	use 'windwp/nvim-autopairs'           -- nvim-autopair
	use 'nvim-tree/nvim-web-devicons'     -- nerdfont icons for plugins
	use 'godlygeek/tabular'               -- aligning on characters

	-- work plugins
	if IS_WORK_DEVICE then
		use 'github/copilot.vim'
		use 'memgraph/cypher.vim'
	end


	-- if bootstrapped then sync all plugins
	if packer_bootstrapped then
		packer.sync()
	end
end)
