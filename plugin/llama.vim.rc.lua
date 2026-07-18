-- Set llama.vim global variables

print("Hello")

-- In neovim, to create a new global variable, you need to use the vim.g table
-- For example, to create a new global variable called llama_config, you would use the following code:
vim.g.llama_config = {
	show_info = false,
	keymap_fim_trigger = "",
	keymap_fim_accept_full = "<C-j>",
	keymap_fim_accept_partial = "<C-k>",
	keymap_fim_accept_word = "",
	keymap_inst_accept = "",
	keymap_inst_trigger = "",
	keymap_inst_retry = "",
	keymap_inst_continue = "",
}
