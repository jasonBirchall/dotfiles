local utils = require('utils')

local cmd = vim.cmd
local indent = 4

-- General
cmd 'filetype plugin indent on'
cmd 'syntax enable'
utils.opt('b', 'expandtab', true) -- convert tabs to spaces
utils.opt('b', 'shiftwidth', indent)
utils.opt('b', 'smartindent', true)
utils.opt('b', 'tabstop', indent)
utils.opt('o', 'clipboard','unnamed,unnamedplus')
utils.opt('o', 'cmdheight', 1)
utils.opt('o', 'encoding', 'UTF-8')
utils.opt('o', 'hidden', true)
utils.opt('o', 'ignorecase', true)
utils.opt('o', 'mouse', 'a')
utils.opt('o', 'ruler', true)
utils.opt('o', 'scrolloff', 4 )
utils.opt('o', 'shiftround', true)
utils.opt('o', 'showmatch', true) -- show matching bracket end
utils.opt('o', 'smartcase', true)
utils.opt('o', 'smarttab', true)
utils.opt('o', 'splitbelow', true)
utils.opt('o', 'splitright', true)
utils.opt('o', 'wildmode', 'list:longest')
utils.opt('w', 'number', true)
utils.opt('w', 'wrap', true)

-- Highlight on yank
cmd 'au TextYankPost * lua vim.highlight.on_yank {on_visual = false}'

-- Commenting
cmd 'autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o'

-- Filetype
cmd 'filetype plugin indent on'

-- Backups
utils.opt('o', 'backup', false)
utils.opt('o', 'swapfile', false)
utils.opt('o', 'wb', false)
utils.opt('o', 'undofile', true) -- persistent undo

-- Jump to the last save place
vim.api.nvim_exec([[
    if has("autocmd")
        au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
    endif
]], true)

-- Spell check for markdown
vim.api.nvim_exec([[
augroup auto_spellcheck
    autocmd!
    autocmd BufNewFile,BufRead *.md setlocal spell
    autocmd BufNewFile,BufRead *.org setfiletype markdown
    autocmd BufNewFile,BufRead *.org setlocal spell
augroup END
]], false)
