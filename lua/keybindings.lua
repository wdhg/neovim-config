local keymap = vim.keymap

keymap.set('n', 'r', ':redo<cr>')
keymap.set({'n', 'i'}, '<f1>', '<nop>')
keymap.set('n', '<tab>', ':Telescope file_browser<cr>', { noremap = true, silent = true })

local last_cmd_win_by_tabpage = {}

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

	-- Get the current window so we can switch back after
	local current_win = vim.api.nvim_get_current_win()

	-- Create a new window and buffer
	if vim.o.lines * 2 > vim.o.columns then
		-- Screen is portrait, divide horizontally
		vim.cmd("botright new")
		-- Resize to be either 1/3 of the screen or 20 lines tall, whatever is smaller
		vim.cmd("resize " .. math.min(22, math.floor(vim.o.lines / 4)))
	else
		-- Screen is landscape, divide vertically
		vim.cmd("botright vnew")
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
	last_cmd_win_by_tabpage[current_tab] = vim.api.nvim_get_current_win()

	vim.fn.termopen(last_cmd)
	vim.cmd("normal! G") -- Go to the end of the output

	-- Return to original window
	local current_win = vim.api.nvim_set_current_win(current_win)
end

local close_

keymap.set('n', '<leader>rx', run_last_cmd)
keymap.set('n', '<leader>rq', run_last_cmd)
