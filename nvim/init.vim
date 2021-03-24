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
  Plug 'vim-airline/vim-airline-themes'
  Plug 'tpope/vim-commentary'
  Plug 'ctrlpvim/ctrlp.vim'
  Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
  Plug 'vim-ruby/vim-ruby'
  Plug 'jiangmiao/auto-pairs'
  Plug 'airblade/vim-gitgutter'
  Plug 'tpope/vim-fugitive'
  Plug 'christoomey/vim-tmux-navigator'
  Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
  Plug 'junegunn/fzf.vim'
  Plug 'sebdah/vim-delve'
  Plug 'troydm/zoomwintab.vim' " zenmode on splits https://vimawesome.com/plugin/zoomwintab-vim

  Plug 'morhetz/gruvbox' "Theme

call plug#end() 

" Key bindings
let mapleader = " "
nnoremap <leader>v :vsplit<CR>
nnoremap <leader>s :split<CR>
nnoremap <leader><Space> :CtrlP<CR>
nnoremap <leader><ENTER> :Goyo<CR>
" gt and gT to navigate tabs
nnoremap <leader>t :tabedit<CR>
map <C-n> :NERDTreeToggle<CR>
"<Ctrl-r> redraws the screen and removes any search highlighting.
nnoremap <leader> r :nohl<CR>
" Shortcutting split navigation, saving a keypress:
map <C-h> <C-w>h
map <C-j> <C-w>j
map <C-k> <C-w>k
map <C-l> <C-w>l
" Spell-check set to <leader>o, 'o' for 'orthography':
map <leader>o :setlocal spell! spelllang=en_gb<CR>

" Set config to .vimrc
" set runtimepath^=~/.vim runtimepath+=/.vim/after
"     let &packpath = &runtimepath
"     source ~/.vimrc

" Some basic stuff
set clipboard+=unnamedplus "https://neovim.io/doc/user/provider.html#provider-clipboard
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
set list lcs=tab:\|\ "Add tramlines to tabbed code
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
set inccommand=nosplit

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
let gruvbox_contrast_dark='hard'
set ffs=unix
set background=dark cursorline termguicolors
colorscheme gruvbox
let g:airline_theme='solarized'
let g:airline_solarized_bg='dark'

" hi! Normal ctermbg=NONE guibg=NONE 
" hi! NonText ctermbg=NONE guibg=NONE guifg=NONE ctermfg=NONE 

" Search and find
set hls is " turns on highlighted search
set ic 	   " turns on case insensitive

" Ruby CoC enable
" Must have solargraph installed using gem install solargraph
let g:coc_global_extensions = ['coc-solargraph']

" Golang stuff
let g:go_fmt_command = "goimports"    " Run goimports along gofmt on each save     
let g:go_auto_type_info = 1           " Automatically get signature/type info for object under cursor
au BufNewFile,BufRead *.go setlocal noet ts=4 sw=4 sts=4 " Golang allows four spaces for a tab
let g:go_highlight_structs = 1 
let g:go_highlight_methods = 1
let g:go_highlight_functions = 1
let g:go_highlight_operators = 1
let g:go_highlight_build_constraints = 1

" Vim settings for tests
let g:go_test_timeout = '10s'
autocmd FileType go nmap <leader>t  <Plug>(go-test)

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
let NERDTreeShowHidden=1
