local status, ollama = pcall(require, 'OllamaCopilot')
if not status then return end

ollama.setup {
	model_name        = "deepseek-coder:1.3b",
	ollama_url        = "http://localhost:11434",
	stream_suggestion = false,
	python_command    = vim.g.python3_host_prog,
	filetypes         = { "python", "lua", "vim", "markdown", "c" },

	ollama_model_opts = {
		num_predict = 40,
		temperature = 0.1,
	},

	keymaps = {
		suggestion    = "<leader>os",
		reject        = "<leader>or",
		insert_accept = "<Tab>",
	},
}
