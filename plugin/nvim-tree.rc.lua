local status, tree = pcall(require, 'nvim-tree')

if (not status) then
  return
end

tree.setup({
  sort_by = "case_sensitive",
  view = {
    adaptive_size = true,
    mappings = {
      list = {
        { key = "<tab>", action = "" },
      },
    },
  },
  renderer = {
    group_empty = true,
  },
  filters = {
    dotfiles = true,
  },
})
