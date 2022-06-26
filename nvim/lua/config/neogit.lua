local utils = require("utils")

utils.map("n", "<Leader>gs", "<cmd>Neogit kind=split<CR>")
utils.map("n", "<Leader>gc", "<cmd>Neogit commit kind=split<CR>")
utils.map("n", "<Leader>gp", "<cmd>Neogit push<CR>")
