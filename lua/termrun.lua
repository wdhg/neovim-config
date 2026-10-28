-- Shared terminal runner.
--
-- One scratch terminal buffer per nvim instance, shown in a split whose
-- orientation matches the screen: horizontal (bottom) when portrait,
-- vertical (right, 1/3 of columns) when landscape.
--
-- Used by <leader>rx/rt/rq and by build-and-debug (<leader>dR).

-- State lives on a table that survives :ReloadConfig: re-executing this
-- module must not make a running terminal (or its buffer) "disappear" from
-- the module's view, or M.run() would spawn a second one.
local M = _G._termrun_state or {}
_G._termrun_state = M
M.wins_by_tabpage = M.wins_by_tabpage or {}

local function oriented_split()
	if vim.o.lines * 2 > vim.o.columns then
		-- Screen is portrait, divide horizontally
		vim.cmd('botright new')
		-- Resize to be either 1/3 of the screen or 20 lines tall, whatever is smaller
		vim.cmd('resize ' .. math.min(10, math.floor(vim.o.lines / 4)))
	else
		-- Screen is landscape, divide vertically
		vim.cmd('botright vnew')
		-- Resize to be 1/3 of the screen
		vim.cmd('vertical resize ' .. math.floor(vim.o.columns / 3))
	end
end

local function close_win()
	local win = M.wins_by_tabpage[vim.api.nvim_get_current_tabpage()]
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end

-- Open `buf` in the oriented split. When `stay` is true the cursor ends up in
-- the terminal window, otherwise it returns to where it came from.
local function open_win(buf, stay)
	close_win()

	local origin = vim.api.nvim_get_current_win()

	oriented_split()

	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	-- Keep track of this window
	M.wins_by_tabpage[vim.api.nvim_get_current_tabpage()] = win
	vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })

	if not stay then
		vim.api.nvim_set_current_win(origin)
	end
	return win
end

function M.close()
	close_win()
end

-- Show the current output without re-running anything
function M.show(stay)
	if M.term_buf and vim.api.nvim_buf_is_valid(M.term_buf) then
		open_win(M.term_buf, stay)
	else
		print('No terminal output yet')
	end
end

function M.is_running()
	return M.term_buf ~= nil
		and vim.api.nvim_buf_is_valid(M.term_buf)
		and M.term_job ~= nil
		and vim.fn.jobwait({ M.term_job }, 0)[1] == -1
end

-- Run `cmd` in the shared terminal. opts:
--   on_exit = function(exit_code) -- called on the main loop when done
--   stay    = boolean             -- leave the cursor in the terminal window
--
-- If a previous command is still running, it is shown but not replaced;
-- returns false in that case, true when the command was started.
function M.run(cmd, opts)
	opts = opts or {}
	if M.is_running() then
		M.show()
		return false
	end

	-- Create a new shared buffer for the terminal
	M.term_buf = vim.api.nvim_create_buf(false, true)
	-- bufhidden must be "hide" so the buffer survives its window being closed
	vim.api.nvim_buf_set_option(M.term_buf, 'bufhidden', 'hide')
	vim.api.nvim_buf_set_option(M.term_buf, 'buftype', 'nofile')
	vim.api.nvim_buf_set_option(M.term_buf, 'swapfile', false)
	vim.api.nvim_buf_set_option(M.term_buf, 'number', false)
	vim.api.nvim_buf_set_option(M.term_buf, 'relativenumber', false)

	open_win(M.term_buf, opts.stay)

	-- termopen targets the current buffer, so scope it to the terminal buffer
	vim.api.nvim_buf_call(M.term_buf, function()
		M.term_job = vim.fn.termopen(cmd, {
			on_exit = function(_, code)
				if opts.on_exit then
					vim.schedule(function()
						opts.on_exit(code)
					end)
				end
			end,
		})
	end)
	return true
end

-- Re-run the most recent `!` shell command from command-line history
function M.rerun_last()
	local history_len = vim.fn.histnr(':')
	local last_cmd = nil
	for i = 1, history_len do
		local cmd = vim.fn.histget(':', -i)
		if cmd:match('^!.*') then
			last_cmd = cmd
			break
		end
	end
	if last_cmd == nil then
		print('No previous shell command found')
		return
	end
	M.run(last_cmd:sub(2))
end

return M
