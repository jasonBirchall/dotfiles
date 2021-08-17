-- restore the session for the current directory
vim.api.nvim_set_keymap("n", "<leader>ls",
                        [[<cmd>lua require("persistence").load()<cr>]], {})

-- restore the last session
vim.api.nvim_set_keymap("n", "<leader>lr",
                        [[<cmd>lua require("persistence").load({ last = true })<cr>]],
                        {})

-- stop Persistence => session won't be saved on exit
vim.api.nvim_set_keymap("n", "<leader>lx",
                        [[<cmd>lua require("persistence").stop()<cr>]], {})
