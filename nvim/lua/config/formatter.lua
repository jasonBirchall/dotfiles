
-- autocmd BufWritePre * undojoin | FormatWrite
-- autocmd for terraform is in ../../ftplugin/tf.lua
vim.api.nvim_exec([[
augroup FormatAutogroup
  autocmd!
  autocmd BufWritePost *.md,*.lua,*.yaml,*.yml,*.go,*.py,*.json,*js FormatWrite
augroup END
]], true)

require("formatter").setup({
    filetype = {
        go = {
            function()
                return {
                    exe = "gofmt",
                    args = {
                        "-w", vim.fn.fnameescape(vim.api.nvim_buf_get_name(0))
                    },
                    stdin = false
                }
            end
        },
        json = {
            function()
                return {
                    exe = "prettier",
                    args = {
                        "--stdin-filepath",
                        vim.fn.fnameescape(vim.api.nvim_buf_get_name(0))
                    },
                    stdin = true
                }
            end
        },
        markdown = {
            function()
                return {
                    exe = "prettier",
                    args = {
                        "--stdin-filepath",
                        vim.fn.fnameescape(vim.api.nvim_buf_get_name(0))
                    },
                    stdin = true
                }
            end
        },
        python = {
            function()
                return {exe = "black", args = {"-"}, stdin = true}
            end
        },
        terraform = {
            function()
                return {exe = "terraform", args = {"fmt", "-"}, stdin = true}
            end
        },
        yaml = {
            function()
                return {
                    -- exe = "yamlfix",
                    -- args = {vim.fn.fnameescape(vim.api.nvim_buf_get_name(0))},
                    exe = "prettier",
                    args = {"--single-quote", "false", "--parser", "yaml"},
                    stdin = true
                }
            end
        }
    }
})
