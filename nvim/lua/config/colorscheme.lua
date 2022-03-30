local utils = require('utils')
local cmd = vim.cmd
utils.opt('o', 'termguicolors', true)
cmd 'set background=dark'
-- cmd 'colorscheme gruvbox'
-- cmd 'colorscheme kanagawa'
-- cmd 'colorscheme gruvbox-material'
-- cmd 'colorscheme github_dimmed'

require("nvim-web-devicons").setup {
  default = true;
}
    
-- cmd 'let g:gruvbox_material_background = "hard"'
cmd 'let g:gruvbox_material_better_performance = 1'
cmd 'let g:gruvbox_material_enable_italic = 1'
cmd 'let g:gruvbox_material_palette = "mix"'
cmd 'colorscheme gruvbox-material'

-- require("github-theme").setup({
--   theme_style = "dark",
--   function_style = "italic",
--   sidebars = {"qf", "vista_kind", "terminal", "packer"},

--   -- Change the "hint" color to the "orange" color, and make the "error" color bright red
--   colors = {hint = "orange", error = "#ff0000"},

--   -- Overwrite the highlight groups
--   overrides = function(c)
--     return {
--       htmlTag = {fg = c.red, bg = "#282c34", sp = c.hint, style = "underline"},
--       DiagnosticHint = {link = "LspDiagnosticsDefaultHint"},
--       -- this will remove the highlight groups
--       TSField = {},
--     }
--   end
-- })
