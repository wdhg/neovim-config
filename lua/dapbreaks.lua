-- Breakpoints panel — prettier than dap-ui's breakpoints element, with
-- jump-to-line (<CR>) and delete (d) keybinds.
--
-- Lists every breakpoint grouped by file, with condition / hit-condition /
-- log-point annotations. Bullets are highlighted with the same highlight
-- groups the gutter signs use.

local M = {}

local win, buf = nil, nil
local line_targets = {} -- lnum -> { bufnr, line }

-- set by dap.rc.lua so deletions write through to the session file
M.persist = nil

local function collect()
	local breakpoints = require('dap.breakpoints')
	local rows = {}
	for bufnr, entries in pairs(breakpoints.get()) do
		local name = vim.api.nvim_buf_get_name(bufnr)
		local rel = name ~= '' and vim.fn.fnamemodify(name, ':~:.') or ('buffer %d'):format(bufnr)
		for _, bp in ipairs(entries) do
			local hl = 'DapBreakpoint'
			local notes = {}
			if bp.condition and bp.condition ~= '' then
				hl = 'DapBreakpointCondition'
				table.insert(notes, 'when ' .. bp.condition)
			end
			if bp.hitCondition and bp.hitCondition ~= '' then
				table.insert(notes, 'hit ' .. bp.hitCondition)
			end
			if bp.logMessage and bp.logMessage ~= '' then
				hl = 'DapLogPoint'
				table.insert(notes, 'log "' .. bp.logMessage .. '"')
			end
			rows[#rows + 1] = {
				bufnr = bufnr,
				line = bp.line,
				rel = rel,
				text = ('● %s:%d'):format(rel, bp.line),
				hl = hl,
				note = #notes > 0 and table.concat(notes, ' · ') or nil,
			}
		end
	end
	table.sort(rows, function(a, b)
		if a.rel ~= b.rel then return a.rel < b.rel end
		return a.line < b.line
	end)
	return rows
end

-- keep live sessions in sync after a deletion, like dap.toggle_breakpoint does
local function sync_sessions(bufnr)
	local dap = require('dap')
	local breakpoints = require('dap.breakpoints')
	for _, s in ipairs(dap.sessions()) do
		local bps = breakpoints.get(bufnr)
		if next(bps) == nil then
			bps[bufnr] = {}
		end
		pcall(function() s:set_breakpoints(bps) end)
	end
end

local function render()
	line_targets = {}
	local rows = collect()
	local lines = {}

	if #rows == 0 then
		lines[1] = 'no breakpoints set'
	else
		for _, row in ipairs(rows) do
			local line = row.text
			if row.note then
				line = line .. '  — ' .. row.note
			end
			lines[#lines + 1] = line
			line_targets[#lines] = { bufnr = row.bufnr, line = row.line }
		end
	end

	-- fill first: extmarks must land on the new content
	vim.api.nvim_buf_set_option(buf, 'modifiable', true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, 'modifiable', false)

	local ns = vim.api.nvim_create_namespace('dapbreaks')
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	if #rows > 0 then
		for i, row in ipairs(rows) do
			-- colour the bullet like the gutter sign, dim the annotation
			vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
				end_col = 1,
				hl_group = row.hl,
			})
			if row.note then
				vim.api.nvim_buf_set_extmark(buf, ns, i - 1, #row.text, {
					end_col = #lines[i],
					hl_group = 'Comment',
				})
			end
		end
	end

	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(l))
	end
	width = math.min(width + 6, math.floor(vim.o.columns * 0.85))
	local height = math.min(math.max(#lines, 3), math.floor(vim.o.lines * 0.8))
	pcall(vim.api.nvim_win_set_config, win, {
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
	})
end

local function jump()
	local lnum = vim.api.nvim_win_get_cursor(win)[1]
	local target = line_targets[lnum]
	if not target then return end

	-- prefer an existing window showing the file
	for _, w in ipairs(vim.fn.win_findbuf(target.bufnr)) do
		if w ~= win then
			vim.api.nvim_set_current_win(w)
			vim.api.nvim_win_set_cursor(w, { target.line, 0 })
			vim.cmd('normal! zz')
			return
		end
	end

	local name = vim.api.nvim_buf_get_name(target.bufnr)
	vim.api.nvim_win_close(win, true)
	vim.cmd('edit ' .. vim.fn.fnameescape(name))
	vim.api.nvim_win_set_cursor(0, { target.line, 0 })
	vim.cmd('normal! zz')
end

local function delete_under_cursor()
	local lnum = vim.api.nvim_win_get_cursor(win)[1]
	local target = line_targets[lnum]
	if not target then return end
	require('dap.breakpoints').remove(target.bufnr, target.line)
	sync_sessions(target.bufnr)
	if M.persist then M.persist() end
	render()
	-- keep the cursor roughly in place
	local max = vim.api.nvim_buf_line_count(buf)
	vim.api.nvim_win_set_cursor(win, { math.min(lnum, max), 0 })
end

function M.show()
	if not (win and vim.api.nvim_win_is_valid(win) and buf and vim.api.nvim_buf_is_valid(buf)) then
		buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
		vim.api.nvim_buf_set_option(buf, 'swapfile', false)
		win = vim.api.nvim_open_win(buf, true, {
			relative = 'editor',
			width = 80,
			height = 10,
			col = math.floor((vim.o.columns - 80) / 2),
			row = math.floor((vim.o.lines - 10) / 2),
			border = 'rounded',
			style = 'minimal',
			title = ' breakpoints — <CR> jump, d delete, q close ',
			title_pos = 'center',
		})

		local function close()
			if win and vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end

		vim.keymap.set('n', '<CR>', jump, { buffer = buf, desc = 'Jump to breakpoint' })
		vim.keymap.set('n', 'd', delete_under_cursor, { buffer = buf, desc = 'Delete breakpoint' })
		vim.keymap.set('n', 'q', close, { buffer = buf, desc = 'Close breakpoints panel' })
		vim.keymap.set('n', '<Esc>', close, { buffer = buf, desc = 'Close breakpoints panel' })
	end

	render()
end

return M