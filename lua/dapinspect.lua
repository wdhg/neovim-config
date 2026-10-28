-- :DapInspect — full-tree variable inspector for an active debug session.
--
-- Prints the expression under the cursor with ALL members expanded, types
-- included. Members (and dereferenced pointers) can be traversed with <CR>,
-- `u` walks back up the traversal history.
--
-- Unlike dap-ui's hover float (which expands one level at a time), this renders
-- the whole subtree at once — at a cost: it fetches every level eagerly, so it
-- caps depth and node counts to keep huge structures from exploding.

local M = {}

local MAX_DEPTH = 1 -- root + immediate members only; go deeper with <CR>
local MAX_CHILDREN = 200
local MAX_LINES = 500

-- state of the single inspector window
local win, buf = nil, nil
local line_exprs = {}      -- lnum -> expression that line can descend into
local history = {}         -- stack of expressions for `u`

local function session()
	local dap = require('dap')
	local s = dap.session()
	if s and s.current_frame then
		return s
	end
end

local function expr_under_cursor()
	if vim.fn.mode() == 'v' or vim.fn.mode() == 'V' then
		local start = vim.fn.getpos('v')
		local finish = vim.fn.getpos('.')
		local lines = vim.fn.getregion(start, finish, { type = vim.fn.mode() })
		return vim.trim(table.concat(lines, ' '))
	end
	return vim.trim(vim.fn.expand('<cexpr>'))
end

-- Build a C expression addressing `child` relative to `parent`.
-- Adapters differ on how they present children:
--   array/index children are named "[3]"            -> base[3]
--   pointer children are the pointee's fields       -> base->field
--   struct children are the struct's fields         -> (base).field
-- NB: pointer chains must use -> so repeated descends grow linearly
-- (parser->tokens_head->next->next) instead of nesting (*(*(*...)))).
local function child_expr(parent, child)
	local base = parent.expr
	if child.name:sub(1, 1) == '[' then
		return base .. child.name
	end
	-- NB: plain=true means the pattern is a literal — '%' would be searched
	-- literally and pointers would never deref (bit us once)
	if parent.type and parent.type:find('*', 1, true) then
		return base .. '->' .. child.name
	end
	return ('(%s).%s'):format(base, child.name)
end

-- null pointers and evaluation errors are leaves — some adapters hand out a
-- variablesReference for them anyway, and recursing produces cascades of
-- synthetic "<parent is NULL>" children
local function nullish(value)
	if not value then return true end
	return value:find('<null>', 1, true) ~= nil
		or value:find('NULL', 1, true) ~= nil
		or value:find('failed to evaluate', 1, true) ~= nil
		or value:match('^0x0+$') ~= nil
		or value:find('<error', 1, true) ~= nil
end

-- async, callback-based subtree gather --------------------------------------------

local gather -- forward declaration (mutual recursion with fetch_children)

local function fetch_children(s, node, done)
	if not node.ref or node.ref == 0 or nullish(node.value) then
		node.children = nil
		done()
		return
	end
	local args = { variablesReference = node.ref }
	-- ask indexed (array) children only up to the cap
	if node.indexed and node.indexed > MAX_CHILDREN then
		args.start = 0
		args.count = MAX_CHILDREN
		node.truncated = true
	end
	if node.named and node.named > MAX_CHILDREN then
		node.truncated = true
	end
	s:request('variables', args, function(err, resp)
		if err or not vim.tbl_contains(require('dap').sessions(), s) then
			node.children = nil
			done()
			return
		end
		local vars = resp and resp.variables or {}
		node.children = {}
		for _, var in ipairs(vars) do
			local child = {
				name = var.name,
				value = var.value,
				type = var.type,
				ref = var.variablesReference or 0,
				indexed = var.indexedVariables,
				named = var.namedVariables,
				-- anonymous members (empty name) have no addressable expression:
				-- display-only, never gathered or descendable
				expr = var.name ~= '' and child_expr(node, var) or nil,
			}
			table.insert(node.children, child)
		end
		local pending = 0
		for _, child in ipairs(node.children) do
			if child.expr then
				pending = pending + 1
				gather(s, child, node.depth + 1, function()
					pending = pending - 1
					if pending == 0 then
						done()
					end
				end)
			end
		end
		if pending == 0 then
			done()
		end
	end)
end

gather = function(s, node, depth, done)
	node.depth = depth
	if depth >= MAX_DEPTH then
		node.children = nil
		node.at_max_depth = (node.ref or 0) > 0
		done()
		return
	end
	fetch_children(s, node, done)
end

-- rendering -----------------------------------------------------------------------
-- Objects render as C-style brace blocks:
--
--   p = {
--     .value = 1,
--     .next = {
--       .value = 2,
--       .next = <null>,
--     },
--   }    (Node *)
--
-- Scalars stay on one line; the type annotation goes on the root's closing
-- brace (or a root scalar's own line).

local function render_lines(root)
	local lines = {}

	local function label_for(node, name)
		if name == nil or name == '' then
			return '(anonymous)'
		end
		if name:sub(1, 1) == '[' then
			return name -- array/map index children already carry brackets
		end
		return '.' .. name
	end

	local function walk(node, indent, label)
		if #lines >= MAX_LINES then return end
		local prefix = ('  '):rep(indent)

		if node.children and #node.children > 0 then
			-- object: multi-line brace block
			table.insert(lines, prefix .. label .. ' = {')
			line_exprs[#lines] = node.expr
			for _, child in ipairs(node.children) do
				local before = #lines
				walk(child, indent + 1, label_for(node, child.name))
				if #lines > before and #lines < MAX_LINES then
					lines[#lines] = lines[#lines] .. ',' -- C-style trailing comma
				end
			end
			if node.truncated then
				table.insert(lines, prefix .. '  ... (more children),')
			end
			local close = prefix .. '}'
			if indent == 0 and node.type then
				close = close .. '    (' .. node.type .. ')'
			end
			table.insert(lines, close)
		else
			-- scalar (or object capped at MAX_DEPTH: show its one-line summary)
			local line = prefix .. label .. ' = ' .. (node.value or '?')
			if node.at_max_depth then
				line = line .. '  … (max depth ' .. MAX_DEPTH .. ')'
			end
			if indent == 0 and node.type then
				line = line .. '    (' .. node.type .. ')'
			end
			table.insert(lines, line)
			line_exprs[#lines] = node.expr
		end
	end

	walk(root, 0, root.expr)
	return lines
end

local function show_float(expr, root)
	line_exprs = {}

	local new_lines = render_lines(root)

	if not (win and vim.api.nvim_win_is_valid(win) and buf and vim.api.nvim_buf_is_valid(buf)) then
		buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
		vim.api.nvim_buf_set_option(buf, 'swapfile', false)
		local width = math.min(100, math.floor(vim.o.columns * 0.85))
		local height = math.min(math.max(#new_lines + 1, 5), math.floor(vim.o.lines * 0.8))
		win = vim.api.nvim_open_win(buf, true, {
			relative = 'editor',
			width = width,
			height = height,
			col = math.floor((vim.o.columns - width) / 2),
			row = math.floor((vim.o.lines - height) / 2),
			border = 'rounded',
			style = 'minimal',
			title = (' inspect: %s '):format(expr),
			title_pos = 'center',
		})
		vim.wo[win].wrap = false

		local function close()
			history = {}
			if win and vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end

		local function descend()
			local lnum = vim.api.nvim_win_get_cursor(win)[1]
			local current = vim.w[win].dap_inspect_expr
			local target = line_exprs[lnum]
			if target and target ~= current then
				history[#history + 1] = current
				M.show(target)
			end
		end

		local function go_back()
			if #history > 0 then
				M.show(table.remove(history))
			end
		end

		vim.keymap.set('n', '<CR>', descend, { buffer = buf, desc = 'Inspect member under cursor' })
		vim.keymap.set('n', 'u', go_back, { buffer = buf, desc = 'Back to previous expression' })
		vim.keymap.set('n', 'q', close, { buffer = buf, desc = 'Close inspector' })
		vim.keymap.set('n', '<Esc>', close, { buffer = buf, desc = 'Close inspector' })
	end

	-- remember what's on display so descend/go_back work after re-shows
	vim.w[win].dap_inspect_expr = expr
	pcall(vim.api.nvim_win_set_config, win, { title = (' inspect: %s  (<CR> descend, u back, q close) '):format(expr) })

	vim.api.nvim_buf_set_option(buf, 'modifiable', true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
	vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

-- entry point ---------------------------------------------------------------------

function M.show(expr)
	local s = session()
	if not s then
		vim.notify('DapInspect needs a stopped debug session', vim.log.levels.WARN)
		return
	end
	if not s.stopped_thread_id then
		vim.notify('Program is running — pause (<leader>dp) or wait for a breakpoint before inspecting', vim.log.levels.WARN)
		return
	end
	if not expr or expr == '' then
		expr = expr_under_cursor()
	end
	if not expr or expr == '' then
		vim.notify('Nothing under the cursor to inspect', vim.log.levels.WARN)
		return
	end
	-- <cexpr> returns bare operator fragments when the cursor sits on the '.'
	-- or '->' of a member access — strip trailing operators and reject
	-- punctuation-only expressions
	expr = vim.trim(expr)
	expr = expr:gsub('[.>%-]+$', '') -- trailing '.' / '->' / '>' fragments
	if expr == '' or not expr:match('[%w_]') then
		vim.notify('Nothing under the cursor to inspect', vim.log.levels.WARN)
		return
	end

	local frame_id = s.current_frame.id
	s:request('evaluate', { expression = expr, context = 'hover', frameId = frame_id }, function(err, resp)
		vim.schedule(function()
			if err or not resp then
				vim.notify('Inspect failed: ' .. vim.inspect(err), vim.log.levels.ERROR)
				return
			end
			if not session() then
				-- previously silent — looked like "the window didn't open"
				vim.notify('Debug session ended before the inspection could render', vim.log.levels.WARN)
				return
			end
			local root = {
				expr = expr,
				value = resp.result,
				type = resp.type,
				ref = resp.variablesReference or 0,
				indexed = resp.indexedVariables,
				named = resp.namedVariables,
			}
			gather(s, root, 0, function()
				vim.schedule(function()
					show_float(expr, root)
				end)
			end)
		end)
	end)
end

return M
