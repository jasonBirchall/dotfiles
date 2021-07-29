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
utils.map('n', '<leader>t', ':spl | terminal<CR>')
utils.map('t', '<Esc>', '<C-\\><C-n>')

-- Split
utils.map('n', '<leader>v', ':vsplit<CR>')
utils.map('n', '<leader>s', ':split<CR>')
utils.map('n', '<leader>V', ':vertical resize 350<CR>')

-- Text, tab
utils.map('n', '<leader>z', ':nohl<CR>')

-- Go
utils.map('n', '<leader>gd', ':GoDocBrowser<CR>')
utils.map('n', '<leader>gt', ':GoTests<CR>')
