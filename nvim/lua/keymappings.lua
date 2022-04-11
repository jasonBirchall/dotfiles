local utils = require('utils')
utils.map('i', 'jk', '<Esc>')           -- jk to escape

-- Navigation
utils.map('n', '<C-h> <C-w>', 'h')
utils.map('n', '<C-j> <C-w>', 'j')
utils.map('n', '<C-k> <C-w>', 'k')
utils.map('n', '<C-w> <C-w>', 'l')

-- Terminal navigation
utils.map('t', '<C-h> <C-W>', 'h')
utils.map('t', '<C-j> <C-W>', 'j')
utils.map('t', '<C-k> <C-W>', 'k')
utils.map('t', '<C-w> <C-W>', 'l')
utils.map('n', '<leader>t', ':FloatermToggle<CR>')
utils.map('t', '<Esc>', '<C-\\><C-n>')

-- Split
utils.map('n', '<leader>v', ':vsplit<CR>')
utils.map('n', '<leader>s', ':split<CR>')
utils.map('n', '<leader>V', ':vertical resize 350<CR>')

-- Text, tab
utils.map('n', '<leader>z', ':nohl<CR>') -- clear highlights
utils.map('n', '<leader>.', ':BufferLineCycleNext<CR>')
utils.map('n', '<leader>,', ':BufferLineCyclePrev<CR>')
utils.map('n', '<leader><', ':BufferLineMovePrev<CR>')
utils.map('n', '<leader>>', ':BufferLineMoveNext<CR>')

-- Trouble
utils.map('n', '<leader>xx', ':TroubleToggle<CR>')

-- Other
utils.map('n', '<leader>w', ':WakaTimeToday<CR>')
