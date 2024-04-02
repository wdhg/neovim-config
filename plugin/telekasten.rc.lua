local status, telekasten = pcall(require, 'telekasten')
if not status then return end

telekasten.setup {
  home = vim.fn.expand("~/zettelkasten"),
}
