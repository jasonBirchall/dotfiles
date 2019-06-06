" Make Vim more useful
set nocompatible
filetype off

" Set the runtime path to include Vundle and initialise
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" Let vundle manage vundle, required
Plugin 'vundleVim/Vundle.vim'

" Basics
Plugin 'godlygeek/tabular'
Plugin 'majutsushi/tagbar'
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'tpope/vim-surround'
Plugin 'mhinz/vim-startify'
Plugin 'scrooloose/nerdtree'
Plugin 'scrooloose/syntastic'
Plugin 'pgilad/vim-skeletons'
Plugin 'airblade/vim-gitgutter'
Plugin 'vim-airline/vim-airline'
Plugin 'scrooloose/nerdcommenter'
Plugin 'Xuyuanp/nerdtree-git-plugin'
Plugin 'enricobacis/vim-airline-clock'
Plugin 'tiagofumo/vim-nerdtree-syntax-highlight'

" Hotkeys
"########

map <F7> gg=G<C-o><C-o> " Reindent

map <leader>T :%s/\s\+$//<CR> " <leader>T = Delete all trailing space in file

map <leader>R :retab<CR> " <leader>R = Converts tabs to spaces in file

" Quick save
map <C-o>w :w!<cr>

" Quick search
map <space> /
map <c-space> ?

" Colourschemes
Plugin 'flazz/vim-colorschemes'
Plugin 'chriskempson/base16-vim'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'kristijanhusak/vim-hybrid-material'

" Coding
Plugin 'lervag/vimtex'        " LaTeX
Plugin 'sheerun/vim-polyglot' " Polyglot

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required


" General
" #######
" Map leader
let mapleader = "/"

" Enable syntax highlighting
syntax enable
syntax on
set shell=/bin/bash
set ruler

set autoread			" Auto read files when changed outside
set mouse =a      " Lets you copy data to system clipboard
set splitright		" Put a new buffer on the right of the current buffer
set splitbelow		" Put new buffer below the current buffer
set guiheadroom=0
set ignorecase		" When searching
set hlsearch			" Highlight the search
set smartcase			" When searching, try to be smart about cases 
set number
set cursorline
set nobackup
set nowb
set noswapfile

" No annoying sound on errors
set noerrorbells
set novisualbell
set t_vb=
set tm=500

let g:tex_flavor = "latext" " Auto detect latex filetype

" Text, tabs and stuff
" ###################
"
set tabstop=2
set shiftwidth=2 " 1 tab == 2 spaces
set softtabstop=2
set smarttab " Be smart when using tabs
set expandtab " Convert tabs to spaces

"set ai " Auto indent
set si " Smart indent
set wrap " Wrap lines

set foldmethod=marker
set foldlevel=0 " Close every fold by default
set modelines=1 " Modeline would be '" vim:foldmethod=marker:foldlevel=0' at the end of file

set backspace=2
set autoindent

" Show matching brackets when text indicator is over them
set showmatch

" Show how many tenths of a second to blink when text indicator is over them
set mat=2

" Add a bit extra margin to the left
set foldcolumn=1

" Moving around
" #############

" Buffer switching left, down, up, right, i.e. moving from one split to other
map <c-h> <c-w>h
map <c-j> <c-w>j
map <c-k> <c-w>k
map <c-l> <c-w>l

" Set 7 lines of buffer when scrolling
set so=7

" Moving lines around
nnoremap <C-j> :m .+1<CR>==
nnoremap <C-k> :m .-2<CR>==
inoremap <C-j> <Esc>:m .+1<CR>==gi
inoremap <C-k> <Esc>:m .-2<CR>==gi
vnoremap <C-j> :m '>+1<CR>gv=gv
vnoremap <C-k> :m '<-2<CR>gv=gv

" Return to last edit position when opening files
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

" Spell checking
" ##############
" Pressing \ss will toggle and untoggle spell checking
map <leader>ss :setlocal spell!<cr>


" Colours and fonts
" #################

set background=dark

" Use Unix as the standard file type
set ffs=unix

colorscheme gruvbox

" Plugins
" #######

"~~~~~~~~~~~~~~~~~~~~
"   6.1 Syntastic   ~
"~~~~~~~~~~~~~~~~~~~~
set statusline+=%#warningmsg#
set statusline+=%*

let g:syntastic_mode_map = { 'mode': 'passive' } "Enable if you want to disable syntastic on file open
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0

let g:syntastic_quiet_messages = {
    \ "level":  "warnings",
    \ "regex": [
        \ '\m\[C03\d\d\]',
        \ '\mpossible unwanted space at "{"'
        \]}


"~~~~~~~~~~~~~~~~~~
"   6.2 Airline   ~
"~~~~~~~~~~~~~~~~~~
set laststatus=2
let g:airline#extensions#tabline#enabled=1
let g:airline_left_sep=''
let g:airline_right_sep=''


"~~~~~~~~~~~~~~~~~~~
"   6.3 Nerdtree   ~
"~~~~~~~~~~~~~~~~~~~
map <F3> :NERDTreeToggle<CR>
map <F4> :Hex<CR>

let NERDTreeShowHidden=1
let NERDTreeShowBookmarks=1

let g:NERDTreeFileExtensionHighlightFullName = 1
let g:NERDTreeExactMatchHighlightFullName = 1
let g:NERDTreePatternMatchHighlightFullName = 1
let g:NERDTreeHighlightFolders = 1 " enables folder icon highlighting using exact match
let g:NERDTreeHighlightFoldersFullName = 1 " highlights the folder name

let NERDTreeIgnore=[
    \ 'node_modules$[[dir]]',
    \ '.git$[[dir]]',
    \ '.vscode$[[dir]]',
    \ '.idea$[[dir]]',
    \ '.DS_Store$[[file]]',
    \ '.swp$[[file]]',
    \ 'hdevtools.sock$[[file]]',
    \ '.synctex.gz[[file]]',
    \ '.fls[[file]]',
    \ '.fdb_latexmk[[file]]',
    \ '.aux[[file]]'
\ ]


" NERDTress File highlighting
function! NERDTreeHighlightFile(extension, fg, bg, guifg, guibg)
 exec 'autocmd filetype nerdtree highlight ' . a:extension .' ctermbg='. a:bg .' ctermfg='. a:fg .' guibg='. a:guibg .' guifg='. a:guifg
 exec 'autocmd filetype nerdtree syn match ' . a:extension .' #^\s\+.*'. a:extension .'$#'
endfunction


"~~~~~~~~~~~~~~~~~~~~~~~~
"   6.4 Nerdcommenter   ~
"~~~~~~~~~~~~~~~~~~~~~~~~
let g:NERDSpaceDelims = 1 " Add spaces after comment delimiters by default
let g:NERDCompactSexyComs = 1 " Use compact syntax for prettified multi-line comments
let g:NERDDefaultAlign = 'left' " Align line-wise comment delimiters flush left instead of following code indentation
let g:NERDAltDelims_java = 1 " Set a language to use its alternate delimiters by default
let g:NERDCustomDelimiters = { 'c': { 'left': '/**','right': '*/' } } " Add your own custom formats or override the defaults
let g:NERDCommentEmptyLines = 1 " Allow commenting and inverting empty lines (useful when commenting a region)
let g:NERDTrimTrailingWhitespace = 1 " Enable trimming of trailing whitespace when uncommenting


"~~~~~~~~~~~~~~~~~
"   6.5 Vimtex   ~
"~~~~~~~~~~~~~~~~~
let g:vimtex_quickfix_ignore_all_warnings = 1
let g:vimtex_quickfix_latexlog = {
    \ 'overfull' : 0,
    \ 'underfull' : 0
    \}


"~~~~~~~~~~~~~~~~~
"   6.6 Tabgar   ~
"~~~~~~~~~~~~~~~~~
nmap <F8> :TagbarToggle<CR>


"~~~~~~~~~~~~~~~~~~~
"   6.7 Snippets   ~
"~~~~~~~~~~~~~~~~~~~
" Vim-addon-manager
fun! SetupVAM()
  let c = get(g:, 'vim_addon_manager', {})
  let g:vim_addon_manager = c
  let c.plugin_root_dir = expand('$HOME', 1) . '/.vim/vim-addons'

  " Force your ~/.vim/after directory to be last in &rtp always:
  " let g:vim_addon_manager.rtp_list_hook = 'vam#ForceUsersAfterDirectoriesToBeLast'

  " most used options you may want to use:
  " let c.log_to_buf = 1
  " let c.auto_install = 0
  let &rtp.=(empty(&rtp)?'':',').c.plugin_root_dir.'/vim-addon-manager'
  if !isdirectory(c.plugin_root_dir.'/vim-addon-manager/autoload')
    execute '!git clone --depth=1 git://github.com/MarcWeber/vim-addon-manager '
        \       shellescape(c.plugin_root_dir.'/vim-addon-manager', 1)
  endif

  " This provides the VAMActivate command, you could be passing plugin names, too
  call vam#ActivateAddons([], {})
endfun
call SetupVAM()

" Vim-snippets and UltiSnips
ActivateAddons vim-snippets UltiSnips

" UltiSnips
let g:UltiSnipsExpandTrigger = "<tab>"
let g:UltiSnipsJumpForwardTrigger = "<C-j>"
let g:UltiSnipsJumpBackwardTrigger = "<s-tab>"


"~~~~~~~~~~~~~~~~~~~
"   6.8 Polyglot   ~
"~~~~~~~~~~~~~~~~~~~
" See https://github.com/sheerun/vim-polyglot
let g:polyglot_disabled = ['latex'] " We use vimtex instead of LaTeX-Box


"~~~~~~~~~~~~~~~~~~~~
"   6.9 Skeletons   ~
"~~~~~~~~~~~~~~~~~~~~
let skeletons#autoRegister = 1 " Auto-register for creation of new files


"~~~~~~~~~~~~~~~~~
"   6.10 CtrlP   ~
"~~~~~~~~~~~~~~~~~
set wildignore+=*/tmp/*,*.so,*.swp,*.zip " MacOSX/Linux
let g:ctrlp_user_command = 'find %s -type f' " MacOSX/Linux

" Ignore files in .gitignore
let g:ctrlp_user_command = ['.git', 'cd %s && git ls-files -co --exclude-standard']

let g:ctrlp_custom_ignore = {
  \ 'dir':  '\v[\/](node_modules|target|dist)|(\.(git|hg|svn))$',
  \ 'file': '\v\.(exe|so|dll|DS_Store)$',
  \ 'link': 'some_bad_symbolic_links',
\ }



set wildmenu
set clipboard=unnamed
