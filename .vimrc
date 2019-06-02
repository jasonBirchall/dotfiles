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

" Colourschemes
Plugin 'chriskempson/base16-vim'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'kristijanhusak/vim-hybrid-material'

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
" Allows you to use option (alt) key to navigate nw
set backspace=2
set autoindent
" Make tabs as wide as two spaces
set tabstop=2
set shiftwidth=2
set softtabstop=2
" Use the OS clipboard by default (on versions compiled with `+clipboard`)
set clipboard=unnamed
