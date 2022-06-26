local utils = require("utils")
local cmd = vim.cmd

-- General
cmd("filetype plugin indent on")
cmd("syntax enable")
utils.opt("o", "clipboard", "unnamed,unnamedplus")
utils.opt("o", "cmdheight", 1)
utils.opt("o", "encoding", "UTF-8")
utils.opt("o", "hidden", true)
utils.opt("o", "ignorecase", true)
utils.opt("o", "mouse", "a")
utils.opt("o", "ruler", true)
utils.opt("o", "scrolloff", 4)
utils.opt("o", "shiftwidth", 3)
utils.opt("o", "showmatch", true) -- show matching bracket end
utils.opt("o", "smartcase", true)
utils.opt("o", "smartindent", true)
utils.opt("o", "smarttab", true)
utils.opt("o", "splitbelow", true)
utils.opt("o", "splitright", true)
utils.opt("o", "tabstop", 3) -- set term gui colors (most terminals support this)
utils.opt("o", "termguicolors", true) -- set term gui colors (most terminals support this)
utils.opt("o", "wildmode", "list:longest")
utils.opt("w", "number", true)
utils.opt("w", "wrap", true)

-- Highlight on yank
cmd("au TextYankPost * lua vim.highlight.on_yank {on_visual = false}")

-- Commenting
cmd("autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o")

-- Filetype
cmd("filetype plugin indent on")

-- Backups
utils.opt("o", "backup", false)
utils.opt("o", "swapfile", false)
utils.opt("o", "wb", false)
utils.opt("o", "undofile", true) -- persistent undo

-- Jump to the last save place
vim.api.nvim_exec(
	[[
    if has("autocmd")
        au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
    endif
]],
	true
)

-- Spell check for markdown
vim.api.nvim_exec(
	[[
augroup auto_spellcheck
    autocmd!
    autocmd BufNewFile,BufRead *.md setlocal spell
    autocmd BufNewFile,BufRead *.org setfiletype markdown
    autocmd BufNewFile,BufRead *.org setlocal spell
augroup END
]],
	false
)

-- Remove all trailing whitespace on save
vim.api.nvim_exec(
	[[
  augroup TrimWhiteSpace
    au!
    autocmd BufWritePre * :%s/\s\+$//e
  augroup END
  ]],
	false
)

-- Prevent new line to also start with a comment
vim.api.nvim_exec(
	[[
  augroup NewLineComment
    au!
    au FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o
  augroup END
  ]],
	false
)

vim.api.nvim_exec(
	[[
 autocmd BufEnter * ++nested if winnr('$') == 1 && bufname() == 'NvimTree_' . tabpagenr() | quit | endif
]],
	false
)
