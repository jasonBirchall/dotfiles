" Abbreviations
abbr teh the

" Make vim useful
set nocompatible
syntax enable
syntax on
set shell=/bin/bash
set ruler
set smartcase " When searching try to be smart about cases
set ignorecase " When searching
filetype plugin indent on
set encoding=utf-8
set t_Co=256
autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o "Ensure comments aren't persisted

" Map leader to spacebar
let mapleader = " "

" Backups 
set nobackup
set nowritebackup
set noswapfile
set nowb

" Put tmp files under .vim/tmp
set undodir=~/.vim/tmp/undo/
set undofile
set backupdir=~/.vim/tmp/backup/
set directory=~/.vim/tmp/swap/

" Clipboard
" You must have vim-gnome, vim-athena, or vim-gtx.
set clipboard=unnamedplus

" Colours and fonts
set background=dark
set ffs=unix
colorscheme gruvbox

" Search and find
set hls is " turns on highlighted search
set ic 	   " turns on case insensitive

"Text, tabs and stuff
set autoindent
set tabstop=2
set shiftwidth=2 " 1 tab = 2 spaces
set softtabstop=2
set smarttab " bE smart when using tabs
set expandtab " Convert tabs to spaces
set showmatch " Show matching brackets when cursored
set wildmenu " Enhanced command line completion
set wrap " Wrap lines
set nu

" Closing brackets
inoremap " ""<left>
inoremap ' ''<left>
inoremap ( ()<left>
inoremap [ []<left>
inoremap { {}<left>

" Navigation
" Splits
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" Ctrl+p settings
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'

