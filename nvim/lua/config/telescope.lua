require('telescope').load_extension('gh')

require("telescope").setup {
  pickers = {
    -- Your special builtin config goes in here
    buffers = {
      sort_lastused = true,
      previewer = true,
    },
    find_files = {
    }
  },
}

local utils = require('utils')

utils.map('n', '<Leader><space>', '<cmd>Telescope find_files hidden=true<CR>')
utils.map('n', '<Leader>fo', '<cmd>Telescope oldfiles<CR>')
utils.map('n', '<Leader>ff', '<cmd>Telescope file_browser hidden=true<CR>')
utils.map('n', '<Leader>gh', '<cmd>Telescope gh pull_request<CR>')
utils.map('n', '<Leader>fl', '<cmd>Telescope live_grep<CR>')
utils.map('n', '<Leader>gc', '<cmd>Telescope git_commits<CR>')
utils.map('n', '<Leader>fc', '<cmd>Telescope commands<CR>')
