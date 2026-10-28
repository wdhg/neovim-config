local status, mason = pcall(require, 'mason')
if not status then return end

-- register-once: mason.setup() adds a fresh ungrouped VimLeavePre autocmd each
-- call, so re-sourcing (e.g. :ReloadConfig) would stack them. The opts below are
-- pure cosmetics; change them and restart, or clear this flag manually.
if not vim.g.mason_configured then
	vim.g.mason_configured = true
	mason.setup({
		ui = {
			border = "rounded",
			icons = {
				package_installed = '+',
				package_pending = '~',
				package_uninstalled = '-',
			},
		}
	})
end

local status, mason_lspconfig = pcall(require, 'mason-lspconfig')
if not status then return end

mason_lspconfig.setup()
