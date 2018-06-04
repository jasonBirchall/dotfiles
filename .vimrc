" Make Vim more useful
set nocompatible
" Use the Solarized Dark theme
set background=dark
colorscheme solarized
let g:solarized_termtrans=1

" Enable syntax highlighting
syntax enable
syntax on
" Enhance command-line completion
set wildmenu
" Ignore case of searches
set ignorecase
set hlsearch
" Enable line numbers
set number
set cursorline
" Show the cursor position
set ruler
set t_Co=256
" Allows you to use option (alt) key to navigate nw
set backspace=2
set autoindent
" Make tabs as wide as two spaces
set tabstop=2
set shiftwidth=2
set softtabstop=2
" Show “invisible” characters
set lcs=tab:▸\ ,trail:·,eol:¬,nbsp:_
set list
set expandtab
" Use the OS clipboard by default (on versions compiled with `+clipboard`)
set clipboard=unnamed
