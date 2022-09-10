let g:grammarous#default_comments_only_filetypes = {
            \ '*' : 1, 'help' : 0, 'markdown' : 0,
            \ }

let g:grammarous#enabled_rules = {'*' : ['PASSIVE_VOICE']}

let g:grammarous#disabled_rules = {
            \ 'markdown' : ['COMMA_PARENTHESIS_WHITESPACE', 'WHITESPACE_RULE'],
            \ }
