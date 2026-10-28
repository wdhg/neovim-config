local M = {}

local function ch(line, i)
	return line:sub(i + 1, i + 1)
end

-- identifier bounds around cursor col (0-based, half-open [s, e))
local function word_bounds(line, col)
	if not ch(line, col):match('[%w_]') then
		return nil
	end
	local s, e = col, col
	while s > 0 and ch(line, s - 1):match('[%w_]') do
		s = s - 1
	end
	while e < #line and ch(line, e):match('[%w_]') do
		e = e + 1
	end
	return s, e
end

-- scan forward from `from` (just past the identifier) for function-like
-- arguments; returns the invocation end (exclusive flat index), or the
-- identifier end itself for object-like macros
local function invocation_end(text, from)
	local i, n = from, #text
	while i <= n and text:sub(i + 1, i + 1):match('%s') do
		i = i + 1
	end
	if text:sub(i + 1, i + 1) ~= '(' then
		return from
	end
	local depth = 0
	while i <= n do
		local c = text:sub(i + 1, i + 1)
		if c == '"' or c == "'" then
			i = i + 1
			while i <= n do
				local q = text:sub(i + 1, i + 1)
				i = i + 1
				if q == '\\' then
					i = i + 1
				elseif q == c then
					break
				end
			end
		elseif c == '/' and text:sub(i + 2, i + 2) == '/' then
			while i <= n and text:sub(i + 1, i + 1) ~= '\n' do
				i = i + 1
			end
		elseif c == '/' and text:sub(i + 2, i + 2) == '*' then
			local close = text:find('*/', i + 3, true)
			if not close then
				return nil
			end
			i = close + 1
		elseif c == '(' then
			depth = depth + 1
			i = i + 1
		elseif c == ')' then
			depth = depth - 1
			i = i + 1
			if depth == 0 then
				return i
			end
		else
			i = i + 1
		end
	end
	return nil
end

-- flat index -> (0-based row, 0-based col)
local function flat_pos(lines, offsets, idx)
	for i = 1, #lines do
		if idx <= offsets[i] + #lines[i] then
			return i - 1, idx - offsets[i]
		end
	end
	return #lines - 1, #lines[#lines]
end

-- split on top-level commas, honoring parens and string literals
local function split_top(s)
	local parts, cur, depth, i = {}, {}, 0, 1
	while i <= #s do
		local c = s:sub(i, i)
		if c == '"' or c == "'" then
			cur[#cur + 1] = c
			i = i + 1
			while i <= #s do
				local q = s:sub(i, i)
				cur[#cur + 1] = q
				i = i + 1
				if q == '\\' then
					if i <= #s then
						cur[#cur + 1] = s:sub(i, i)
						i = i + 1
					end
				elseif q == c then
					break
				end
			end
		elseif c == '(' or c == '[' or c == '{' then
			depth = depth + 1
			cur[#cur + 1] = c
			i = i + 1
		elseif c == ')' or c == ']' or c == '}' then
			depth = depth - 1
			cur[#cur + 1] = c
			i = i + 1
		elseif c == ',' and depth == 0 then
			parts[#parts + 1] = table.concat(cur)
			cur = {}
			i = i + 1
		else
			cur[#cur + 1] = c
			i = i + 1
		end
	end
	parts[#parts + 1] = table.concat(cur)
	return parts
end

local function tokenize(cmd)
	local parts, i = {}, 1
	while i <= #cmd do
		local c = cmd:sub(i, i)
		if c:match('%s') then
			i = i + 1
		elseif c == '"' then
			local j = cmd:find('"', i + 1, true) or #cmd
			parts[#parts + 1] = cmd:sub(i + 1, j - 1)
			i = j + 1
		else
			local j = cmd:find('%s', i) or #cmd + 1
			parts[#parts + 1] = cmd:sub(i, j - 1)
			i = j
		end
	end
	return parts
end

local VALUE_FLAGS = { ['-o'] = true, ['-MF'] = true, ['-MT'] = true, ['-MQ'] = true }
local KEEP_VALUE_FLAGS = { ['-I'] = true, ['-L'] = true, ['-include'] = true, ['-isystem'] = true, ['-x'] = true }

-- keep flags relevant to preprocessing, drop -o/-c/sources/etc
local function preprocessor_args(args)
	local out, i = {}, 1
	while i <= #args do
		local a = args[i]
		if VALUE_FLAGS[a] then
			i = i + 2
		elseif a == '-c' or a == '-E' then
			i = i + 1
		elseif a:sub(1, 1) == '-' then
			out[#out + 1] = a
			i = i + 1
			if KEEP_VALUE_FLAGS[a] and i <= #args then
				out[#out + 1] = args[i]
				i = i + 1
			end
		else
			i = i + 1
		end
	end
	return out
end

-- returns (extra args, cwd to run the compiler in)
local function flags_for(bufname)
	local dir = bufname ~= '' and vim.fs.dirname(bufname) or vim.loop.cwd()
	local cc = vim.fs.find('compile_commands.json', { upward = true, path = dir })[1]
	if not cc then
		return {}, dir
	end
	local ok, db = pcall(function()
		return vim.json.decode(table.concat(vim.fn.readfile(cc), '\n'))
	end)
	if not ok or type(db) ~= 'table' then
		return {}, vim.fs.dirname(cc)
	end
	local norm = vim.fs.normalize(bufname)
	local entry
	for _, e in ipairs(db) do
		local f = vim.fs.normalize(e.file or '')
		if f == norm or vim.fs.basename(f) == vim.fs.basename(norm) then
			entry = e
			break
		end
	end
	if not entry then
		return {}, vim.fs.dirname(cc)
	end
	local args = entry.arguments or tokenize(entry.command or '')
	return preprocessor_args(args), vim.fs.dirname(cc)
end

local function parse_params(s)
	local params, va_name = {}, nil
	for _, p in ipairs(split_top(s)) do
		p = vim.trim(p)
		if p:sub(-3) == '...' then
			local n = vim.trim(p:sub(1, -4))
			va_name = n ~= '' and n or '__VA_ARGS__'
		elseif p ~= '' then
			params[#params + 1] = p
		end
	end
	return params, va_name
end

local function find_definition(def_lines, name)
	for _, l in ipairs(def_lines) do
		local rest = l:match('^#define%s+(.+)$')
		if rest then
			local n = rest:match('^([%w_]+)')
			if n == name then
				local after = rest:sub(#n + 1, #n + 1)
				if after == '(' then
					local plist = rest:match('^%b()', #n + 1)
					if plist then
						local params, va = parse_params(plist:sub(2, -2))
						return {
							is_func = true,
							params = params,
							va = va,
							body = vim.trim(rest:sub(#n + 1 + #plist)),
						}
					end
				end
				return { is_func = false, body = vim.trim(rest:sub(#n + 1)) }
			end
		end
	end
end

-- single-step argument substitution into a macro body
local function substitute(def, args)
	local body = def.body
	local params = def.params or {}
	local map, names = {}, {}

	for i, p in ipairs(params) do
		map[p] = args[i] or ''
		names[#names + 1] = p
	end
	if def.va then
		local rest = {}
		for i = #params + 1, #args do
			rest[#rest + 1] = args[i]
		end
		map[def.va] = table.concat(rest, ', ')
		names[#names + 1] = def.va
	end

	-- GNU comma-swallow: ", ## __VA_ARGS__" vanishes on empty varargs
	if def.va then
		body = body:gsub(',%s*##%s*%f[%w_]' .. def.va .. '%f[^%w_]', function()
			return map[def.va] == '' and '' or (', ' .. map[def.va])
		end)
	end

	-- stringify: #param -> "arg"
	for _, name in ipairs(names) do
		local arg = map[name] or ''
		body = body:gsub('%f[#]#%s*%f[%w_]' .. name .. '%f[^%w_]', function()
			return '"' .. arg:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
		end)
	end

	-- plain substitution at token boundaries
	for _, name in ipairs(names) do
		local arg = map[name] or ''
		body = body:gsub('%f[%w_]' .. name .. '%f[^%w_]', function()
			return arg
		end)
	end

	-- token pasting
	body = body:gsub('%s*##%s*', '')

	return body
end

function M.expand()
	local bufname = vim.api.nvim_buf_get_name(0)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1

	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local text = table.concat(lines, '\n')
	local offsets, off = {}, 0
	for i, l in ipairs(lines) do
		offsets[i] = off
		off = off + #l + 1
	end

	local line = lines[row + 1] or ''
	local s, e = word_bounds(line, col)
	if not s then
		vim.notify('Cursor is not on a macro name', vim.log.levels.WARN)
		return
	end
	local start_flat = offsets[row + 1] + s
	local end_flat = invocation_end(text, start_flat + (e - s))
	if not end_flat then
		vim.notify('Could not find end of macro invocation', vim.log.levels.WARN)
		return
	end
	local name = text:sub(start_flat + 1, start_flat + (e - s))

	local args, cwd = flags_for(bufname)
	local compiler
	if vim.fn.executable('clang') == 1 then
		compiler = 'clang'
	elseif vim.fn.executable('gcc') == 1 then
		compiler = 'gcc'
	elseif vim.fn.executable('cc') == 1 then
		compiler = 'cc'
	else
		vim.notify('No C compiler (clang/gcc/cc) found', vim.log.levels.ERROR)
		return
	end

	local dir = bufname ~= '' and vim.fs.dirname(bufname) or vim.loop.cwd()
	local ext = vim.fn.fnamemodify(bufname, ':e')
	local tmp = dir .. '/.nvim_macro_expand_tmp' .. (ext ~= '' and '.' .. ext or '')
	vim.fn.writefile(lines, tmp)

	local cmd = vim.list_extend({ compiler, '-E', '-dM' }, args)
	cmd[#cmd + 1] = tmp
	local res = vim.system(cmd, { cwd = cwd, text = true }):wait()
	os.remove(tmp)
	if res.code ~= 0 then
		local err = vim.trim(res.stderr or ''):gsub('\n', ' | '):sub(1, 200)
		vim.notify('Macro expansion failed: ' .. (err ~= '' and err or ('no output from ' .. compiler)),
			vim.log.levels.ERROR)
		return
	end

	local def = find_definition(vim.split(res.stdout or '', '\n'), name)
	if not def then
		vim.notify('No #define found for ' .. name, vim.log.levels.WARN)
		return
	end

	local has_parens = end_flat > start_flat + #name
	if def.is_func and not has_parens then
		vim.notify(name .. ' is function-like and needs arguments', vim.log.levels.WARN)
		return
	end

	local call_args = {}
	if def.is_func then
		local orig = text:sub(start_flat + 1, end_flat)
		local lp = orig:find('(', 1, true)
		for _, a in ipairs(split_top(orig:sub(lp + 1, #orig - 1))) do
			call_args[#call_args + 1] = vim.trim(a)
		end
	elseif has_parens then
		-- object-like macro followed by parens: only expand the name itself
		end_flat = start_flat + #name
	end

	local exp = substitute(def, call_args)

	local rs, rsc = flat_pos(lines, offsets, start_flat)
	local re, rec = flat_pos(lines, offsets, end_flat)
	local prefix = lines[rs + 1]:sub(1, rsc)
	local suffix = lines[re + 1]:sub(rec + 1)
	local indent = prefix:match('^%s*') or ''
	local exp_lines = vim.split(exp, '\n')
	local new = { prefix .. vim.trim(exp_lines[1]) }
	for k = 2, #exp_lines do
		new[k] = indent .. vim.trim(exp_lines[k])
	end
	new[#new] = new[#new] .. suffix
	vim.api.nvim_buf_set_lines(0, rs, re + 1, false, new)
end

return M
