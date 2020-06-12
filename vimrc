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
au BufNewFile,BufRead *.go setlocal noet ts=4 sw=4 sts=4 " Golang allows four spaces for a tab

" Navigation
" Splits
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>
:set list lcs=tab:\|\ "Add tramlines to tabbed code

" Jump back to last position in file
if has("autocmd")
  au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
endif

" Move lines up and down
nnoremap <S-j> :m .+1<CR>==
nnoremap <S-k> :m .-2<CR>==
inoremap <S-j> <Esc>:m .+1<CR>==gi
inoremap <S-k> <Esc>:m .-2<CR>==gi
vnoremap <S-j> :m '>+1<CR>gv=gv
vnoremap <S-k> :m '<-2<CR>gv=gv

" Go auto format, import and autocomplete
" autocmd FileType go autocmd BufWritePre <buffer> GoFmt
let g:go_fmt_command = "goimports"
let g:go_auto_type_info = 1
au filetype go inoremap <buffer> . .<C-x><C-o>


"<Ctrl-r> redraws the screen and removes any search highlighting.
nnoremap <silent> <C-r> :nohl<CR>

" Ctrl+p settings
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'

" Nerdtree settings
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif "Closes vim if the only window left open is a NERDTree
map <C-n> :NERDTreeToggle<CR>

" Syntastic plugin
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
let g:syntastic_go_checkers = ['gofmt']
