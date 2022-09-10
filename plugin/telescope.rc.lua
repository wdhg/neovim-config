local status, telescope = pcall(require, 'telescope')

if (not status) then
  return
end

telescope.setup {
  extensions = {
    file_browser = {
      -- theme = "ivy",
      -- disables netrw and use telescope-file-browser in its place
      hijack_netrw = true,
      mappings = {
        ["i"] = {
        },
        ["n"] = {
        },
      },
    },
  },
}

telescope.load_extension "file_browser"
