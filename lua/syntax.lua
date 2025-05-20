vim.opt.termguicolors = true
vim.opt.cursorline = false

-- Optionally all highlight groups
if true then
	for _, group in ipairs(vim.fn.getcompletion('', 'highlight')) do
		vim.cmd('highlight! ' .. group .. ' NONE')
	end
end

function hi(val, names)
	for _, name in ipairs(names) do
		vim.api.nvim_set_hl(0, name, val)
	end
end

-- Basic vim
hi({ fg = '#F0D4A1',  bg = '#0b2824' }, {'Normal'})
hi({ fg = '',         bg = '#374e4a' }, {'Visual'})
hi({ fg = '#0b2824',  bg = '#E7B76A' }, {'Search'})
hi({ fg = '',         bg = '#05100e' }, {'StatusLine'})
hi({ fg = '',         bg = '#0c201d' }, {'StatusLineNC'})
hi({ fg = '#2b433f',  bg = ''        }, {'Whitespace'})
-- Git Gutter
hi({ fg = '#00ff00',  bg = ''        }, {'GitGutterAdd'})
hi({ fg = '#ffff00',  bg = ''        }, {'GitGutterChange'})
hi({ fg = '#ff0000',  bg = ''        }, {'GitGutterDelete'})
-- Tree sitter 
hi({ fg = '#dfdbe4',  bg = '#354C1A' }, {'@comment'})
hi({ fg = '#7ABC62',  bg = ''        }, {'@keyword'})
hi({ fg = '#D5E24C',  bg = ''        }, {'@string'})
hi({ fg = '#9d8f78',  bg = ''        }, {'@operator'})
hi({ fg = '#7EDDC3',  bg = ''        }, {'@boolean', '@number'})
hi({ fg = '#AADF9B',  bg = ''        }, {'@type', '@type.builtin', 'Type'})
