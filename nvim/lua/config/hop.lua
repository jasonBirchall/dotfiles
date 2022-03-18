require('hop').setup({
  key = 'etovxqpdygfblzhckisuran',
})

local utils = require('utils')

utils.map('n', '<Leader>hw', '<cmd>HopWord<CR>')
utils.map('n', '<Leader>hl', '<cmd>HopLine<CR>')

