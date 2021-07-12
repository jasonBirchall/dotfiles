local utils = require('utils')
utils.map('n', '<C-l>', '<cmd>noh<CR>') -- Clear highlights
utils.map('i', 'jk', '<Esc>')           -- jk to escape

-- Navigation
utils.map('n', '<C-h> <C-w>', 'h')
utils.map('n', '<C-j> <C-w>', 'j')
utils.map('n', '<C-k> <C-w>', 'k')
utils.map('n', '<C-w> <C-w>', 'l')
