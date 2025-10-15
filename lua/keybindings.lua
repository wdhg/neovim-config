local keymap = vim.keymap

keymap.set('n', 'r', ':redo<cr>')
keymap.set({'n', 'i'}, '<f1>', '<nop>')
keymap.set('n', '<tab>', ':Telescope file_browser<cr>', { noremap = true, silent = true })

-- Running commands in vim

local last_cmd_win_by_tabpage = {}

local close_cmd_win = function()
	local current_tab = vim.api.nvim_get_current_tabpage()
	if last_cmd_win_by_tabpage[current_tab] then
		local last_cmd_win = last_cmd_win_by_tabpage[current_tab]
		if last_cmd_win and vim.api.nvim_win_is_valid(last_cmd_win) then
			for _,win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				if win == last_cmd_win then
					vim.api.nvim_win_close(last_cmd_win, true)
					break
				end
			end
		end
	end
end

local run_last_cmd = function()
	-- First we find the last command
	-- We loop through the history in reverse order until we find a ! command
	local history_len = vim.fn.histnr(":")
	local last_cmd = nil
	for i=1,history_len do
		cmd = vim.fn.histget(":", -i)
		if cmd:match("^!.*") then
			last_cmd = cmd
			break
		end
	end
	if last_cmd == nil then
		print("No previous shell command found")
		return
	end
	last_cmd = last_cmd:sub(2)

	-- Close previous window if it is open in current tab
	close_cmd_win()

	-- Get the current window so we can switch back after
	local current_win = vim.api.nvim_get_current_win()

	-- Create a new window and buffer
	if vim.o.lines * 2 > vim.o.columns then
		-- Screen is portrait, divide horizontally
		vim.cmd("botright new")
		-- Resize to be either 1/3 of the screen or 20 lines tall, whatever is smaller
		vim.cmd("resize " .. math.min(10, math.floor(vim.o.lines / 4)))
	else
		-- Screen is landscape, divide vertically
		vim.cmd("botright vnew")
		-- Resize to be 1/3 of the screen
		vim.cmd("vertical resize " .. math.floor(vim.o.columns / 3))
	end

	local buf = vim.api.nvim_get_current_buf()
	-- Reset the buffer if it was already open
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})    -- Clear all lines
	vim.api.nvim_buf_set_option(buf, "modified", false)  -- Mark as unmodified
	-- Make the buffer temporary (scratch-like)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")  -- Remove buffer when closed
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")  -- No associated file
	vim.api.nvim_buf_set_option(buf, "swapfile", false)    -- Disable swap file
	-- Disable line numbers
	vim.api.nvim_buf_set_option(buf, "number", false)
	vim.api.nvim_buf_set_option(buf, "relativenumber", false)
	-- Keep track of this window
	local current_tab = vim.api.nvim_get_current_tabpage()
	last_cmd_win_by_tabpage[current_tab] = vim.api.nvim_get_current_win()

	vim.fn.termopen(last_cmd)
	vim.cmd("normal! G") -- Go to the end of the output

	-- Return to original window
	local current_win = vim.api.nvim_set_current_win(current_win)
end

keymap.set('n', '<leader>rx', run_last_cmd)
keymap.set('n', '<leader>rq', close_cmd_win)

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
