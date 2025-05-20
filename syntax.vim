set background=dark
hi clear

if exists("syntax_on")
  "syntax clear
  "syntax on
  syntax reset
endif

let g:colors_name = "dragon-energy"

" ------------------------------------------------------------------------------
"                                    code
" ------------------------------------------------------------------------------

hi Comment         guifg=#ffff00

hi String          guifg=#90fe40
hi Character       guifg=#00dd55
hi Number          guifg=#11ccff
hi Boolean         guifg=#c088ff
hi Float           guifg=#11ccff

hi Statement       guifg=#ff4477

hi Error           guifg=#ffffff       guibg=#ff0000

hi Todo            guifg=#000000       guibg=#ffff00

hi ColorColumn                         guibg=#161616
hi CursorLine                          guibg=#161616
" ------------------------------------------------------------------------------
"                                 plugins
" ------------------------------------------------------------------------------

" Git Gutter
hi GitGutterAdd    guifg=#00ff00       guibg=#0e0e0e
hi GitGutterChange guifg=#ffff00       guibg=#0e0e0e
hi GitGutterDelete guifg=#ff0000       guibg=#0e0e0e

" Coc (:help coc-highlights)
hi CocHintSign     guifg=#3c3c3c
hi CocFloating                         guibg=#1e1e1e

" Treesitter
hi @markup.heading guifg=#ffff00
