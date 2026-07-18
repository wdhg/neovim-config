local status, gen = pcall(require, 'gen')
if not status then return end

gen.setup {
	model = "mistral-nemo", -- The default model to use.
	quit_map = "q", -- set keymap to close the response window
	retry_map = "<c-r>", -- set keymap to re-send the current prompt
	accept_map = "<c-cr>", -- set keymap to replace the previous selection with the last result
	host = "localhost", -- The host running the Ollama service.
	port = "11434", -- The port on which the Ollama service is listening.
	display_mode = "float", -- The display mode. Can be "float" or "split" or "horizontal-split" or "vertical-split".
	show_prompt = false, -- Shows the prompt submitted to Ollama. Can be true (3 lines) or "full".
	show_model = false, -- Displays which model you are using at the beginning of your chat session.
	think = false,
	no_auto_close = false, -- Never closes the window automatically.
	file = false, -- Write the payload to a temporary file to keep the command short.
	hidden = false, -- Hide the generation window (if true, will implicitly set `prompt.replace = true`), requires Neovim >= 0.10
	init = function(options) pcall(io.popen, "ollama serve > /dev/null 2>&1 &") end,
	-- Function to initialize Ollama
	command = function(options)
		local body = {model = options.model, think = false, stream = true}
		return "curl --silent --no-buffer -X POST http://" .. options.host .. ":" .. options.port .. "/api/chat -d $body"
	end,
	-- The command for the Ollama service. You can use placeholders $prompt, $model and $body (shellescaped).
	-- This can also be a command string.
	-- The executed command must return a JSON object with { response, context }
	-- (context property is optional).
	-- list_models = '<omitted lua function>', -- Retrieves a list of model names
	result_filetype = "markdown", -- Configure filetype of the result buffer
	debug = false -- Prints errors and the command which is run.
}


gen.prompts["G"] = {
	prompt = function()
		-- Get text before the cursor
		local row, col = unpack(vim.api.nvim_win_get_cursor(0))
		local lines = vim.api.nvim_buf_get_lines(0, 0, row, false)
		local text_before = table.concat(lines, "\n")
		-- Get text after the cursor
		local lines_after = vim.api.nvim_buf_get_lines(0, row - 1, -1, false)
		local text_after = table.concat(lines_after, "\n")
		return "Context before:\n```$filetype\n" .. text_before .. "\n```\n\nContext after:\n```$filetype\n" .. text_after .. "\n```\n\nAct on the following request, outputing the result in the format:\n```$filetype\n...\n```\nAvoid outputting any code provided in the context, the code you generate will go between the before and after contexts provided prior. Avoid generating any chat which isn't code related.\n\nRequest: $input"
	end,
	replace = true,
	extract = "```$filetype\n(.-)\n```",
}

vim.keymap.set('n', '<leader>g', ":Gen G<CR>", { noremap = true, silent = true })
