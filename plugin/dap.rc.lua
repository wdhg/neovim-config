-- Debug Adapter Protocol setup (C/C++ via codelldb)
--
-- Debug session state — build command, program, args, breakpoints, watch
-- expressions — is stored per-project in .nvim/dap.json (legacy .dapsession.json
-- in the project root is still read), so <leader>dR and <leader>dc work across
-- runs and restarts without re-asking.

local status, dap = pcall(require, 'dap')
if not status then return end

-- note: not exposed as dap.breakpoints — this version lazy-imports it internally
local breakpoints = require('dap.breakpoints')

local termrun = require('termrun')
local dapbreaks = require('dapbreaks')

-- forward-declared: the watches helpers below reference these, and a `local`
-- declared later in the file wouldn't be in scope for them (it would compile
-- as a global lookup and always be nil)
local status_dapui, dapui
local persist_breakpoints -- defined with breakpoints_by_file() near the end

-- per-project session state -------------------------------------------------------

local function session_file()
	return vim.fn.getcwd() .. '/.nvim/dap.json'
end

local function load_session()
	-- current location first, then the legacy root file
	for _, path in ipairs({ session_file(), vim.fn.getcwd() .. '/.dapsession.json' }) do
		local f = io.open(path, 'r')
		if f then
			local data = f:read('*a')
			f:close()
			local ok, decoded = pcall(vim.json.decode, data)
			if ok and type(decoded) == 'table' then
				return decoded
			end
		end
	end
	return {}
end

local function save_session(session)
	-- don't litter projects that never had debug state
	local has_content = session.build
		or (session.launch and (session.launch.program or session.launch.args))
		or (session.breakpoints and next(session.breakpoints))
		or (session.watches and next(session.watches))
	local exists = vim.fn.filereadable(session_file()) == 1
	if not has_content and not exists then
		return
	end
	vim.fn.mkdir(vim.fs.dirname(session_file()), 'p')
	local f = io.open(session_file(), 'w')
	if f then
		f:write(vim.json.encode(session))
		f:close()
	end
end

local function update_session(fn)
	local session = load_session()
	fn(session)
	save_session(session)
	return session
end

local function has_program(session)
	local launch = session.launch
	return launch and launch.program and launch.program ~= ''
end

-- dap-ui layout, orientation-aware ------------------------------------------------
-- Just the console (the program's stdout/stderr) — other panels are available
-- on demand as floats: <leader>ds scopes, <leader>dw watches, <leader>dk stacks,
-- <leader>dq breakpoints, <leader>dr repl

local last_orientation = nil

local layouts_for_screen = function()
	if vim.o.lines * 2 > vim.o.columns then
		-- Portrait: bottom tray, like the <leader>rx terminal split
		return {
			{
				elements = { 'console' },
				size = math.min(10, math.floor(vim.o.lines / 4)),
				position = 'bottom',
			},
		}
	else
		-- Landscape: one right-hand column at 1/3 of the screen, like <leader>rx
		return {
			{
				elements = { 'console' },
				size = math.floor(vim.o.columns / 3),
				position = 'right',
			},
		}
	end
end

-- open one dap-ui element as a centered floating window
local function float_element(name)
	if not status_dapui then return end
	local ok, win = pcall(dapui.float_element, name)
	if not ok then
		vim.notify('No debug session for the ' .. name .. ' panel yet', vim.log.levels.WARN)
	end
end

-- watch expression persistence ----------------------------------------------------

local function watches_from_ui()
	if not (status_dapui and dapui.elements and dapui.elements.watches) then
		return nil
	end
	local ok, watches = pcall(dapui.elements.watches.get)
	if not ok or type(watches) ~= 'table' then
		return nil
	end
	local exprs = {}
	for _, watch in ipairs(watches) do
		if watch.expression and watch.expression ~= '' then
			exprs[#exprs + 1] = watch.expression
		end
	end
	return exprs
end

-- the element instances are recreated on every dapui.setup(), so restoring
-- right after a setup can never double-add
local function restore_watches()
	if not (status_dapui and dapui.elements and dapui.elements.watches) then
		return
	end
	for _, expr in ipairs(load_session().watches or {}) do
		pcall(dapui.elements.watches.add, expr)
	end
end

-- console autoscroll --------------------------------------------------------------
-- dap-ui's console autoscroll only runs while the console window has focus.
-- This keeps every window showing the console pinned to the last line — and
-- stops fighting the user once they scroll up (scrolled-up = bottom of the
-- window no longer shows the last line; scrolling back down re-engages).

local console_attached_buf = nil

local function console_bufnr()
	if not status_dapui then return nil end
	local ok, buf = pcall(function() return dapui.elements.console.buffer() end)
	if ok and buf and vim.api.nvim_buf_is_valid(buf) then return buf end
	return nil
end

local function pin_console_to_end()
	local buf = console_bufnr()
	if not buf then return end

	if console_attached_buf ~= buf then
		console_attached_buf = buf
		vim.api.nvim_buf_attach(buf, false, {
			on_lines = function()
				-- schedule so line_count reflects the completed update
				vim.schedule(function()
					local ok_count, last = pcall(vim.api.nvim_buf_line_count, buf)
					if not ok_count or last <= 0 or not vim.api.nvim_buf_is_valid(buf) then return end
					for _, win in ipairs(vim.fn.win_findbuf(buf)) do
						if vim.w[win].dap_console_follow ~= false then
							vim.api.nvim_win_set_cursor(win, { last, 0 })
						end
					end
				end)
			end,
		})
	end

	-- also catch up right now (e.g. output arrived while unattached)
	local last = vim.api.nvim_buf_line_count(buf)
	if last > 0 then
		for _, win in ipairs(vim.fn.win_findbuf(buf)) do
			if vim.w[win].dap_console_follow ~= false then
				vim.api.nvim_win_set_cursor(win, { last, 0 })
			end
		end
	end
end

local status_dapui_result, dapui_obj = pcall(require, 'dapui')
status_dapui, dapui = status_dapui_result, dapui_obj
local DAPUI_ICONS = {
	-- dap-ui defaults are codicons (private-use glyphs most fonts lack — they
	-- show as tofu). These are ordinary geometric shapes with wide coverage.
	expanded = '▾',
	collapsed = '▸',
	current_frame = '→',
}

-- recompute the dap-ui layout. Called from the launch keymaps BEFORE a session
-- starts — never inside a dap event handler: setup() recreates element buffers
-- (including the console the session writes to), which races with a starting
-- session and causes flaky output/panel behaviour.
local function refresh_dapui_layout()
	if not status_dapui then return end
	local orientation = vim.o.lines * 2 > vim.o.columns and 'portrait' or 'landscape'
	if orientation ~= last_orientation then
		last_orientation = orientation
		dapui.setup({ layouts = layouts_for_screen(), icons = DAPUI_ICONS })
		restore_watches()
		console_attached_buf = nil
	end
end

-- breakpoints are restored from the session file on BufReadPost only — so
-- files never opened in this nvim instance would launch with NO breakpoints
-- (the adapter never learns about them). Load every breakpointed file before
-- launching so the session always gets the full set.
local function ensure_breakpoints_loaded()
	local breakpoints = require('dap.breakpoints')
	for path, bps in pairs(load_session().breakpoints or {}) do
		if vim.fn.filereadable(path) == 1 then
			local bufnr = vim.fn.bufadd(path)
			-- only restore files NOT already open: for loaded buffers the
			-- in-memory state is authoritative (nvim-dap sends breakpoints.get()
			-- at session start), so re-applying the session file here would
			-- resurrect breakpoints deleted earlier in this nvim session
			if vim.api.nvim_buf_is_valid(bufnr) and not vim.api.nvim_buf_is_loaded(bufnr) then
				pcall(vim.fn.bufload, bufnr)
				vim.bo[bufnr].buflisted = false -- don't clutter the buffer list
				for _, bp in ipairs(bps) do
					breakpoints.set({
						condition = bp.condition,
						hitCondition = bp.hitCondition,
						log_message = bp.logMessage,
					}, bufnr, bp.line)
				end
			end
		end
	end
end

if status_dapui then
	last_orientation = vim.o.lines * 2 > vim.o.columns and 'portrait' or 'landscape'
	-- NB: setup takes { layouts = ... }, not the layouts list itself — passing
	-- it bare silently keeps the default layout (bit us once)
	dapui.setup({ layouts = layouts_for_screen(), icons = DAPUI_ICONS })
	restore_watches()

	if require('dap').session() then
		-- reloading config mid-session: setup() closed the open layouts, so
		-- reopen them (and re-attach console autoscroll — the element buffers
		-- were recreated by setup())
		console_attached_buf = nil
		dapui.open()
	end
	pin_console_to_end()

	-- per-window autoscroll toggle: while the bottom of the window shows the
	-- last console line, keep following; once the user scrolls up, stop
	-- chasing the output until they scroll back down (or hit G)
	vim.api.nvim_create_augroup('DapConsoleFollow', { clear = true })
	vim.api.nvim_create_autocmd('WinScrolled', {
		group = 'DapConsoleFollow',
		callback = function(ev)
			-- nvim 0.12 gives the scrolled window id in ev.match (as a string)
			local win = tonumber(ev.match)
			if not win or vim.api.nvim_win_get_buf(win) ~= console_bufnr() then return end
			local last = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
			-- nil counts as "follow", so a freshly opened window chases output
			vim.w[win].dap_console_follow = last <= 0 or vim.fn.line('w$', win) == last
		end,
	})

	-- open/close the dap-ui windows automatically
	dap.listeners.after.event_initialized['dapui_config'] = function()
		dapui.open()
		pin_console_to_end()
	end
	dap.listeners.before.event_terminated['dapui_config'] = function()
		update_session(function(s)
			local exprs = watches_from_ui()
			if exprs then s.watches = exprs end
		end)
		-- NB: no dapui.close() — the console stays open so the final program
		-- output remains readable after the run ends
	end
	dap.listeners.before.event_exited['dapui_config'] = function()
		update_session(function(s)
			local exprs = watches_from_ui()
			if exprs then s.watches = exprs end
		end)
	end
end

-- install the codelldb adapter through mason
-- register-once: setup() registers its own autocmds/handlers, so re-sourcing
-- (:ReloadConfig) would stack them — same reason mason.setup() is guarded
local status_mason, mason_nvim_dap = pcall(require, 'mason-nvim-dap')
if status_mason and not vim.g.mason_nvim_dap_configured then
	vim.g.mason_nvim_dap_configured = true
	mason_nvim_dap.setup({
		ensure_installed = { 'codelldb' },
		automatic_installation = true,
	})
end

dap.adapters.codelldb = {
	type = 'server',
	port = '${port}',
	executable = {
		command = vim.fn.stdpath('data') .. '/mason/bin/codelldb',
		args = { '--port', '${port}' },
	},
}

-- the launch configuration reads the session file at launch time, so edits
-- (e.g. via <leader>dC) take effect without reloading this file
dap.configurations.c = {
	{
		name = 'Launch',
		type = 'codelldb',
		request = 'launch',
		program = function()
			local session = load_session()
			if has_program(session) then
				return session.launch.program
			end
			vim.notify('No debug configuration — set it with <leader>dC', vim.log.levels.WARN)
			return nil
		end,
		cwd = '${workspaceFolder}',
		stopOnEntry = false,
		args = function()
			local args = (load_session().launch or {}).args
			return args and vim.split(args, ' ', { trimempty = true }) or {}
		end,
	},
}
-- same config for C++
dap.configurations.cpp = dap.configurations.c

-- session config editor popup -----------------------------------------------------

-- A small editable popup listing build command / program / args. <CR> saves
-- (and optionally chains into an action), q/<Esc> aborts.
local function open_session_editor(on_save)
	local session = load_session()
	local launch = session.launch or {}
	local lines = {
		('build:   %s'):format(session.build or ''),
		('program: %s'):format(launch.program or ''),
		('args:    %s'):format(launch.args or ''),
	}

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
	vim.api.nvim_buf_set_option(buf, 'swapfile', false)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local width = math.min(80, math.floor(vim.o.columns * 0.9))
	local height = #lines + 2
	local win = vim.api.nvim_open_win(buf, true, {
		relative = 'editor',
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		border = 'rounded',
		style = 'minimal',
		title = ' dap session — <CR> save, q abort ',
		title_pos = 'center',
	})
	vim.wo[win].cursorline = true

	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end

	local function save_and_close()
		local values = {}
		for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
			local key, value = line:match('^%s*(%a+)%s*:%s*(.*)$')
			if key then
				values[key] = vim.trim(value)
			end
		end

		local program = values.program ~= '' and vim.fn.fnamemodify(values.program, ':p') or nil
		update_session(function(s)
			s.build = values.build ~= '' and values.build or nil
			s.launch = { program = program, args = values.args or '' }
		end)
		if program and vim.fn.filereadable(program) ~= 1 then
			vim.notify('Warning: ' .. program .. " doesn't exist yet (fine if it gets built)", vim.log.levels.WARN)
		end

		close()
		if on_save then
			on_save()
		end
	end

	vim.keymap.set('n', '<CR>', save_and_close, { buffer = buf, desc = 'Save dap session config' })
	vim.keymap.set('n', 'q', close, { buffer = buf, desc = 'Abort without saving' })
	vim.keymap.set('n', '<Esc>', close, { buffer = buf, desc = 'Abort without saving' })
end

-- keybindings: build & debug ------------------------------------------------------

local keymap = vim.keymap

-- Launch a FRESH debug session. Never lets dap.run() send a DAP restart:
-- with a session already active (same config name) dap.run() turns into a
-- restart request, and codelldb's restart re-spawns through a stale launch
-- context — failing with "Cannot launch ... DupDescriptor-open failed" even
-- though the rebuilt binary exists.
local function launch_debug()
	refresh_dapui_layout()
	ensure_breakpoints_loaded()
	local function run()
		dap.run(dap.configurations.c[1], { new = true })
	end
	if dap.session() then
		dap.terminate({ on_done = function()
			vim.schedule(run)
		end })
	else
		run()
	end
end

-- gdb-c-style continue: resume a stopped session; fresh launch otherwise
local function start_debug()
	local session = load_session()
	if not has_program(session) then
		open_session_editor(start_debug)
		return
	end
	if dap.session() then
		if dap.session().stopped_thread_id then
			dap.continue()
		else
			vim.notify('Program is already running — wait for a breakpoint or terminate with <leader>dt', vim.log.levels.INFO)
		end
		return
	end
	launch_debug()
end
keymap.set('n', '<leader>dc', start_debug, { desc = 'Start/continue debugging' })

-- run the build script in the shared <leader>rx terminal, then debug on success.
-- An empty build command in the editor means "debug without building".
local function build_and_debug()
	local session = load_session()
	if not has_program(session) then
		open_session_editor(build_and_debug)
		return
	end
	if not session.build then
		launch_debug()
		return
	end

	local started = termrun.run(session.build, {
		on_exit = function(code)
			if code == 0 then
				termrun.close() -- build log served its purpose; debugger output takes over
				launch_debug()
			else
				vim.notify('Build failed (' .. code .. ') — not starting debugger', vim.log.levels.ERROR)
				termrun.show(true) -- focus the build output
			end
		end,
	})
	if not started then
		vim.notify('Another command is still running in the shared terminal', vim.log.levels.WARN)
	end
end
keymap.set('n', '<leader>dR', build_and_debug, { desc = 'Rebuild & debug' })

-- edit the remembered build command / program / args
keymap.set('n', '<leader>dC', function()
	open_session_editor(nil)
end, { desc = 'Edit debug session config' })
vim.api.nvim_create_user_command('DapConfig', function()
	open_session_editor(nil)
end, { desc = 'Edit the dap session config (build, program, args)' })

-- dap keybind help popup ----------------------------------------------------------
-- <leader>dh opens a cheat sheet of all debugger keybinds. The single-key
-- stepping keys are only live while the session is stopped at a breakpoint.

local dap_help = {
	{ 'session', {
		{ '<leader>dR', 'rebuild (build cmd in the rx terminal), then debug' },
		{ '<leader>dc', 'start/continue debugging (remembers program/args)' },
		{ '<leader>dC', 'edit session config: build cmd, program, args' },
	} },
	{ 'stepping — gdb-style chords', {
		{ '<leader>ds', 'step (into) — like gdb s' },
		{ '<leader>dn', 'step next / over — like gdb n' },
		{ '<leader>dO', 'step out — like gdb finish' },
		{ '<leader>dH', 'step back (rewind execution)' },
		{ '<leader>dc', 'continue / start' },
		{ '<leader>di / do', 'aliases for ds / dn' },
	} },
	{ 'program control', {
		{ '<leader>dp', 'pause a running program' },
		{ '<leader>dt', 'terminate session / kill program' },
	} },
	{ 'breakpoints', {
		{ '<leader>db', 'toggle breakpoint on current line' },
		{ '<leader>dB', 'conditional breakpoint (prompt for condition)' },
	} },
	{ 'inspecting', {
		{ '<leader>de', 'inspect: full expanded tree with types (<CR> descend, u back)' },
		{ '<leader>dE', 'hover: lightweight one-value dap-ui float' },
	} },
	{ 'panels (floating windows)', {
		{ '<leader>dS', 'scopes (variables)' },
		{ '<leader>dw', 'watches' },
		{ '<leader>dk', 'stacks (call stack)' },
		{ '<leader>dq', 'breakpoints — <CR> jump to line, d delete' },
		{ '<leader>dr', 'REPL' },
		{ '<leader>du', 'toggle the console window' },
	} },
}

local function open_help()
	local lines = {}
	for _, section in ipairs(dap_help) do
		local title, binds = section[1], section[2]
		lines[#lines + 1] = title .. ':'
		for _, b in ipairs(binds) do
			lines[#lines + 1] = ('  %-13s %s'):format(b[1], b[2])
		end
		lines[#lines + 1] = ''
	end
	table.remove(lines) -- drop the trailing blank

	local hbuf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(hbuf, 'bufhidden', 'wipe')
	vim.api.nvim_buf_set_option(hbuf, 'swapfile', false)
	vim.api.nvim_buf_set_lines(hbuf, 0, -1, false, lines)
	vim.bo[hbuf].modifiable = false

	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, #l)
	end
	width = math.min(width + 4, math.floor(vim.o.columns * 0.9))
	local height = math.min(#lines, math.floor(vim.o.lines * 0.85))
	local hwin = vim.api.nvim_open_win(hbuf, true, {
		relative = 'editor',
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		border = 'rounded',
		style = 'minimal',
		title = ' dap keys — q to close ',
		title_pos = 'center',
	})
	vim.wo[hwin].cursorline = false

	local function close()
		if vim.api.nvim_win_is_valid(hwin) then
			vim.api.nvim_win_close(hwin, true)
		end
	end
	vim.keymap.set('n', 'q', close, { buffer = hbuf, desc = 'Close help' })
	vim.keymap.set('n', '<Esc>', close, { buffer = hbuf, desc = 'Close help' })
end

keymap.set('n', '<leader>dh', open_help, { desc = 'DAP keybind help' })
vim.api.nvim_create_user_command('DapHelp', open_help, { desc = 'Show the dap keybind cheat sheet' })

-- remaining step controls ---------------------------------------------------------

keymap.set('n', '<leader>db', function()
	dap.toggle_breakpoint()
	persist_breakpoints()
end, { desc = 'Toggle breakpoint' })
keymap.set('n', '<leader>dB', function()
	dap.set_breakpoint(vim.fn.input('Breakpoint condition: '))
	persist_breakpoints()
end, { desc = 'Conditional breakpoint' })
keymap.set('n', '<leader>do', function() dap.step_over() end, { desc = 'Step over' })
keymap.set('n', '<leader>di', function() dap.step_into() end, { desc = 'Step into' })
keymap.set('n', '<leader>dO', function() dap.step_out() end, { desc = 'Step out' })
keymap.set('n', '<leader>dH', function() dap.step_back() end, { desc = 'Step back' })
keymap.set('n', '<leader>dp', function() dap.pause() end, { desc = 'Pause (interrupt running program)' })
keymap.set('n', '<leader>dt', function() dap.terminate() end, { desc = 'Terminate debug session' })
keymap.set('n', '<leader>du', function() dapui.toggle() end, { desc = 'Toggle debug UI' })
keymap.set('n', '<leader>dr', function() float_element('repl') end, { desc = 'Open REPL (float)' })
-- gdb-style stepping names: s = step (into), n = next (over)
keymap.set('n', '<leader>ds', function() dap.step_into() end, { desc = 'Step into (gdb s)' })
keymap.set('n', '<leader>dn', function() dap.step_over() end, { desc = 'Step over / next (gdb n)' })
keymap.set('n', '<leader>dS', function() float_element('scopes') end, { desc = 'Scopes panel (float)' })
keymap.set('n', '<leader>dw', function() float_element('watches') end, { desc = 'Watches panel (float)' })
keymap.set('n', '<leader>dk', function() float_element('stacks') end, { desc = 'Stacks panel (float)' })
keymap.set('n', '<leader>dq', function() dapbreaks.show() end, { desc = 'Breakpoints panel (jump/delete)' })

-- full-tree variable inspector
local dapinspect = require('dapinspect')
-- de = full inspector (brace-style tree); dE keeps the lightweight dap-ui hover
keymap.set('n', '<leader>de', function() dapinspect.show(nil) end, { desc = 'Inspect variable (full tree)' })
keymap.set('n', '<leader>dE', function() dapui.eval() end, { desc = 'Hover: evaluate expression under cursor' })
vim.api.nvim_create_user_command('DapInspect', function(opts)
	dapinspect.show(opts.args ~= '' and opts.args or nil)
end, { nargs = '?', desc = 'Inspect an expression as a full expanded tree' })

-- signs shown in the gutter on breakpoint/current lines (DapBreakpointCondition
-- and friends must exist or conditional breakpoints throw E155)
local dap_signs = {
	{ name = 'DapBreakpoint',          text = '●', texthl = 'DapBreakpoint' },
	{ name = 'DapBreakpointCondition', text = '◆', texthl = 'DapBreakpointCondition' },
	{ name = 'DapLogPoint',            text = '▶', texthl = 'DapLogPoint' },
	{ name = 'DapBreakpointRejected',  text = '✗', texthl = 'DapBreakpointRejected' },
	{ name = 'DapStopped',             text = '→', texthl = 'DapStopped', linehl = 'DapStoppedLine' },
}
for _, sign in ipairs(dap_signs) do
	vim.fn.sign_define(sign.name, {
		text = sign.text,
		texthl = sign.texthl,
		linehl = sign.linehl or '',
		numhl = '',
	})
end
vim.api.nvim_set_hl(0, 'DapStoppedLine', { bg = '#374e4a' })

-- breakpoint persistence ----------------------------------------------------------
-- Breakpoints are keyed by absolute file path (bufnrs don't survive a restart).

local function breakpoints_by_file()
	local by_file = {}
	for bufnr, bps in pairs(breakpoints.get()) do
		local name = vim.api.nvim_buf_get_name(bufnr)
		if name ~= '' then
			by_file[name] = vim.tbl_map(function(bp)
				return {
					line = bp.line,
					condition = bp.condition,
					hitCondition = bp.hitCondition,
					logMessage = bp.logMessage,
				}
			end, bps)
		end
	end
	return by_file
end

-- write-through: the session file only had breakpoints at VimLeavePre, so a
-- breakpoint removed mid-session survived in the file and came back on the
-- next launch. Persist on every change instead.
-- NB: plain `function`, not `local function` — a second `local` would shadow
-- the forward declaration above and leave the keymap closures calling nil
function persist_breakpoints()
	update_session(function(s)
		s.breakpoints = breakpoints_by_file()
	end)
end
dapbreaks.persist = persist_breakpoints

local dap_augroup = vim.api.nvim_create_augroup('DapBreakpointPersistence', { clear = true })

vim.api.nvim_create_autocmd('VimLeavePre', {
	group = dap_augroup,
	callback = function()
		update_session(function(s)
			s.breakpoints = breakpoints_by_file()
			local exprs = watches_from_ui()
			if exprs then s.watches = exprs end
		end)
	end,
})

vim.api.nvim_create_autocmd('BufReadPost', {
	group = dap_augroup,
	pattern = { '*.c', '*.h', '*.cpp', '*.hpp', '*.cc', '*.cxx', '*.hh', '*.hxx' },
	callback = function(ev)
		-- nvim_buf_get_name is always absolute; ev.file is the name as typed
		local fname = vim.api.nvim_buf_get_name(ev.buf)
		local session = load_session()
		local bps = session.breakpoints and session.breakpoints[fname]
		if not bps then return end
		for _, bp in ipairs(bps) do
			breakpoints.set({
				condition = bp.condition,
				hitCondition = bp.hitCondition,
				log_message = bp.logMessage,
			}, ev.buf, bp.line)
		end
	end,
})
