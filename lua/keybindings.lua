local keymap = vim.keymap

keymap.set('n', 'r', ':redo<cr>')
keymap.set({'n', 'i'}, '<f1>', '<nop>')
keymap.set('n', '<tab>', ':Telescope file_browser<cr>', { noremap = true, silent = true })

local run_code = function(type)
	return function()
		if type == 'repeat' then
				vim.fn.system('tmux send-keys -t 2 Up Enter')
				return
		end

		local ft = vim.bo.filetype
		if ft == 'rust' then
			if type == 'run' then
				vim.fn.system('tmux send-keys -t 2 "cargo run" Enter')
			elseif type == 'test' then
				vim.fn.system('tmux send-keys -t 2 "cargo test" Enter')
			elseif type == 'build' then
				vim.fn.system('tmux send-keys -t 2 "cargo build" Enter')
			end
		elseif ft == 'c' then
			if type == 'run' then
				vim.fn.system('tmux send-keys -t 2 "make run" Enter')
			elseif type == 'test' then
				vim.fn.system('tmux send-keys -t 2 "make test" Enter')
			elseif type == 'build' then
				vim.fn.system('tmux send-keys -t 2 "make build" Enter')
			end
		end
	end
end

keymap.set('n', '<leader>rr', run_code('run'))
keymap.set('n', '<leader>rt', run_code('test'))
keymap.set('n', '<leader>rb', run_code('build'))
keymap.set('n', '<leader>rx', run_code('repeat'))
