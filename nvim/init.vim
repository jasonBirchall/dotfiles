" Plugins
" https://github.com/junegunn/vim-plug
if empty(glob('$HOME/.config/nvim/autoload/plug.vim'))
  silent !curl -fLo $HOME/.config/nvim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('$HOME/.config/nvim/plugged')
  Plug 'neoclide/coc.nvim'
  Plug 'junegunn/limelight.vim'
  Plug 'tpope/vim-surround'
  Plug 'preservim/nerdtree'
  Plug 'junegunn/goyo.vim'
  Plug 'bling/vim-airline'
  Plug 'tpope/vim-commentary'
  Plug 'ctrlpvim/ctrlp.vim'
  Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
  Plug 'vim-ruby/vim-ruby'
  Plug 'jiangmiao/auto-pairs'
  Plug 'airblade/vim-gitgutter'
  Plug 'tpope/vim-fugitive'

  Plug 'morhetz/gruvbox' "Theme
call plug#end() 

" Key bindings
nnoremap <leader><Space> :CtrlP<CR>
nnoremap <leader><ENTER> :Goyo<CR>
map <C-n> :NERDTreeToggle<CR>
" Shortcutting split navigation, saving a keypress:
map <C-h> <C-w>h
map <C-j> <C-w>j
map <C-k> <C-w>k
map <C-l> <C-w>l

" Set config to .vimrc
" set runtimepath^=~/.vim runtimepath+=/.vim/after
"     let &packpath = &runtimepath
"     source ~/.vimrc

" Some basic stuff
set clipboard+=unnamedplus "https://neovim.io/doc/user/provider.html#provider-clipboard
let mapleader =" "
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
set number
au BufNewFile,BufRead *.go setlocal noet ts=4 sw=4 sts=4 " Golang allows four spaces for a tab

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

" Jump back to last position in file
if has("autocmd")
  au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
endif

" Color Settings
colorscheme gruvbox
set background=dark cursorline termguicolors
hi! Normal ctermbg=NONE guibg=NONE 
hi! NonText ctermbg=NONE guibg=NONE guifg=NONE ctermfg=NONE 

" Search and find
set hls is " turns on highlighted search
set ic 	   " turns on case insensitive

" Spell-check set to <leader>o, 'o' for 'orthography':
map <leader>o :setlocal spell! spelllang=en_gb<CR>

" Golang stuff
let g:go_fmt_command = "goimports"    " Run goimports along gofmt on each save     
let g:go_auto_type_info = 1           " Automatically get signature/type info for object under cursor

" Goyo settings
function! s:goyo_enter()
    set number
    set noshowmode
    set noshowcmd
    set nocursorline
    CocDisable
    Limelight
endfunction

function! s:goyo_leave()
    set showmode
    set showcmd
    set cursorline
    CocEnable
    Limelight!
endfunction

autocmd! User GoyoEnter nested call <SID>goyo_enter()
autocmd! User GoyoLeave nested call <SID>goyo_leave()

" Nerd tree
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif "Closes vim if the only window left open is a NERDTree

" https://github.com/neoclide/coc.nvim
" Use tab for trigger completion with characters ahead and navigate.
" NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
" other plugin before putting this into your config.
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction
