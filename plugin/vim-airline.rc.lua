vim.g.airline_powerline_fonts = 1
vim.g.airline_extensions      = { 'tabline', 'hunks' }

function get_git_branch()
	-- Get directory of open file so we can run the command in that directory
	local filename = vim.api.nvim_buf_get_name(0)         -- Get the full path of the current buffer
	local dir      = vim.fn.fnamemodify(filename, ":p:h") -- Extract the directory from the file path
	local opts     = {
		text = true, -- Replace \r\n with \n in output
		cwd  = dir,  -- Change directory of executed command to parent directory of open file
	}
	local branch   = vim.system({'git', 'rev-parse', '--abbrev-ref', 'HEAD'}, opts):wait().stdout
	if branch == nil or branch == '' then
		return ''
	end
	branch = branch:gsub('%s+$', '') -- Remove trailing newline
	return ' ' .. branch .. '  '
end

function airline_init()
	vim.g.airline_section_b = '%{v:lua.get_git_branch()}' .. vim.g.airline_section_b
end
vim.cmd('autocmd User AirlineAfterInit call v:lua.airline_init()')
