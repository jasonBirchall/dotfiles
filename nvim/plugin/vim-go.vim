au BufNewFile,BufRead *.go setlocal noet ts=4 sw=4 sts=4 " Golang allows four spaces for a tab
let g:go_fmt_command = "goimports"    " Run goimports along gofmt on each save     
let g:go_highlight_build_constraints = 1
let g:go_highlight_extra_types = 1
let g:go_highlight_fields = 1
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_operators = 1
let g:go_highlight_structs = 1 
let g:go_highlight_types = 1
let g:go_highlight_variable_declarations = 1
let g:go_highlight_format_strings = 1
let g:go_highlight_string_spellcheck = 1
let g:go_highlight_function_calls = 1
