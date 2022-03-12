local utils = require('utils')
local cmd = vim.cmd
utils.opt('o', 'termguicolors', true)
cmd 'set background=dark'
cmd 'colorscheme gruvbox'
-- cmd 'colorscheme gruvbox-material'

require("nvim-web-devicons").setup {
  default = true;
}
