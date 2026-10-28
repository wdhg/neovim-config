local keymap = vim.keymap

keymap.set('n', 'r', ':redo<cr>')
keymap.set({'n', 'i'}, '<f1>', '<nop>')
keymap.set('n', '<tab>', ':Telescope file_browser<cr>', { noremap = true, silent = true })

-- Running commands in vim
-- The shared terminal lives in lua/termrun.lua so other features (dap's
-- build-and-debug) can run commands in the same oriented split.

require('termrun')

keymap.set('n', '<leader>rx', require('termrun').rerun_last)
keymap.set('n', '<leader>rt', function()
	require('termrun').show() -- View the terminal output without re-running anything
end)
keymap.set('n', '<leader>rq', require('termrun').close)

-- Converting cases

local function get_word_bounds()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_current_line()

	local start_col = col
	local end_col = col

	-- Expand to left
	while start_col > 0 and line:sub(start_col, start_col):match("[%w_]") do
		start_col = start_col - 1
	end
	-- Expand to right
	while end_col <= #line and line:sub(end_col + 1, end_col + 1):match("[%w_]") do
		end_col = end_col + 1
	end

	return row, start_col + 1, end_col
end

local function split_to_parts(word)
	local parts = {}

	-- Normalize underscores to spaces for initial splitting
	word = word:gsub("_", " ")

	-- Split camelCase / PascalCase / numbers / acronyms / etc.
	for part in word:gmatch("[A-Z]?[a-z0-9]+") do
		table.insert(parts, part:lower())
	end

	-- Fallback for all-uppercase (like SCREAMING_CASE)
	if #parts == 0 then
		for part in word:gmatch("[A-Z]+") do
			table.insert(parts, part:lower())
		end
	end

	return parts
end

function to_snake_case()
	local row, start_col, end_col = get_word_bounds()
	local line = vim.api.nvim_get_current_line()
	local word = line:sub(start_col, end_col)

	local parts = split_to_parts(word)
	local snake = table.concat(parts, "_"):lower()

	local new_line = line:sub(1, start_col - 1) .. snake .. line:sub(end_col + 1)
	vim.api.nvim_set_current_line(new_line)
end

function to_camel_case()
	local row, start_col, end_col = get_word_bounds()
	local line = vim.api.nvim_get_current_line()
	local word = line:sub(start_col, end_col)

	local parts = split_to_parts(word)
	for i = 2, #parts do
		parts[i] = parts[i]:gsub("^%l", string.upper)
	end
	local camel = table.concat(parts, "")

	local new_line = line:sub(1, start_col - 1) .. camel .. line:sub(end_col + 1)
	vim.api.nvim_set_current_line(new_line)
end

function to_pascal_case()
	local row, start_col, end_col = get_word_bounds()
	local line = vim.api.nvim_get_current_line()
	local word = line:sub(start_col, end_col)

	local parts = split_to_parts(word)
	for i = 1, #parts do
		parts[i] = parts[i]:gsub("^%l", string.upper)
	end
	local pascal = table.concat(parts, "")

	local new_line = line:sub(1, start_col - 1) .. pascal .. line:sub(end_col + 1)
	vim.api.nvim_set_current_line(new_line)
end

function to_screaming_snake_case()
	local row, start_col, end_col = get_word_bounds()
	local line = vim.api.nvim_get_current_line()
	local word = line:sub(start_col, end_col)
	local parts = split_to_parts(word)
	local scream = table.concat(parts, "_"):upper()
	local new_line = line:sub(1, start_col - 1) .. scream .. line:sub(end_col + 1)
	vim.api.nvim_set_current_line(new_line)
end

vim.keymap.set('n', '<leader>cs', to_snake_case, { noremap = true, silent = true })
vim.keymap.set('n', '<leader>cS', to_screaming_snake_case, { noremap = true, silent = true })
vim.keymap.set('n', '<leader>cc', to_camel_case, { noremap = true, silent = true })
vim.keymap.set('n', '<leader>cp', to_pascal_case, { noremap = true, silent = true })

-- Jumping words in identifiers

function jump_to_next_subword()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_current_line()
	local len = #line
	local i = col + 1

	while i < len do
		local prev, curr = line:sub(i, i), line:sub(i + 1, i + 1)
		if prev == '_' or (prev:match('%l') and curr:match('%u')) then
			vim.api.nvim_win_set_cursor(0, { row, i })
			return
		end
		i = i + 1
	end

	vim.api.nvim_win_set_cursor(0, { row, len})
end

vim.keymap.set('n', '<leader>w', jump_to_next_subword, { noremap = true, silent = true })
