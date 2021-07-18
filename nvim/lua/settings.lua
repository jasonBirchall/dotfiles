local utils = require('utils')

local cmd = vim.cmd
local indent = 4

-- General
cmd 'syntax enable'
cmd 'filetype plugin indent on'
utils.opt('b', 'expandtab', true) -- convert tabs to spaces
utils.opt('b', 'shiftwidth', indent)
utils.opt('o', 'smarttab', true)
utils.opt('b', 'smartindent', true)
utils.opt('b', 'tabstop', indent)
utils.opt('o', 'showmatch', true) -- show matching bracket end
utils.opt('o', 'clipboard','unnamed,unnamedplus')
utils.opt('o', 'hidden', true)
utils.opt('o', 'ignorecase', true)
utils.opt('o', 'mouse', 'a')
utils.opt('o', 'scrolloff', 4 )
utils.opt('o', 'shiftround', true)
utils.opt('o', 'smartcase', true)
utils.opt('o', 'splitbelow', true)
utils.opt('o', 'splitright', true)
utils.opt('o', 'wildmode', 'list:longest')
utils.opt('w', 'number', true)
utils.opt('w', 'wrap', true)
utils.opt('o', 'ruler', true)
utils.opt('o', 'encoding', 'UTF-8')

-- Highlight on yank
cmd 'au TextYankPost * lua vim.highlight.on_yank {on_visual = false}'

-- Commenting
cmd 'autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o'

-- Filetype
cmd 'filetype plugin indent on'

-- Backups
-- utils.opt('b', 'nobackup', true)
