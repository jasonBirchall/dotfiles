local utils = require('utils')
utils.map('n', '<Leader>gs', '<cmd>Gstatus<CR>')  -- Git status
utils.map('n', '<Leader>gv', '<cmd>Gvdiffsplit<CR>')  -- Git diff split vertically
utils.map('n', '<Leader>gb', '<cmd>GBrowse<CR>')  -- View git commit in web browser
utils.map('n', '<Leader>gc', '<cmd>Gcommit<CR>')  -- Commit stage
utils.map('n', '<Leader>gp', '<cmd>Gpush<CR>')  -- Push changes
