local nvim_lsp = require("lspconfig")

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").update_capabilities(capabilities)

local servers = {
    "gopls", "bashls", "pyright", "dockerls", "terraformls",
}
-- Use a loop to conveniently call 'setup' on multiple servers
for _, lsp in ipairs(servers) do
    nvim_lsp[lsp].setup {
        capabilities = capabilities,
        settings = {
            gopls = {analyses = {unusedparams = false}, staticcheck = true},
            python = {analyses = {autoSearchPaths = true, diagnosticMode = "workspace", useLibraryCodeForTypes = true}},
        },
        flags = {debounce_text_changes = 150}
    }
    require"lsp_signature".setup({
        bind = true, -- This is mandatory, otherwise border config won't get registered.
        floating_window = true, -- show hint in a floating window, set to false for virtual text only mode
        doc_lines = 2, -- Set to 0 for not showing doc
        hint_prefix = "🐼 ",
        -- use_lspsaga = false,  -- set to true if you want to use lspsaga popup
        handler_opts = {
            border = "shadow" -- double, single, shadow, none
        }
    })
end

