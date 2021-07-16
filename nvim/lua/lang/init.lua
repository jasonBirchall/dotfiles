-- Your custom attach function for nvim-lspconfig goes here.
local on_attach = function(client, bufnr)
    require('lang.keybindings')

    local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
    local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

    buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

    -- Mappings
    local opts = { noremap=true, silent=true }
    buf_set_keymap('n', 'gD', '<Cmd>lua vim.lsp.buf.declaration()<CR>', opts)
    buf_set_keymap('n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>', opts)
    buf_set_keymap('n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>', opts)
    buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
    buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
    buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
    buf_set_keymap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
    buf_set_keymap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)

end

require'lspconfig'.gopls.setup{}
-- LSPs
-- local servers = {"pyright", "gopls"}
-- for _, lsp in ipairs(servers) do
--     nvim_lsp[lsp].setup {capabilities = capabilities, on_attach = on_attach}
-- end
-- LSPs
-- local servers = { "gopls" }
-- for _, lsp in ipairs(servers) do
--     nvim_lsp[lsp].setup { 
--         capabilities = capabilities;
--         on_attach = on_attach;
--         init_options = {
--             onlyAnalyzeProjectsWithOpenFiles = true,
--             suggestFromUnimportedLibraries = false,
--             closingLabels = true,
--         };
--     }
-- end

-- To get builtin LSP running, do something like:
-- NOTE: This replaces the calls where you would have before done `require('nvim_lsp').sumneko_lua.setup()`
-- require('nlua.lsp.nvim').setup(require('lspconfig'), {
--   on_attach = on_attach,
-- })

-- require('lspconfig.gopls').setup(require('lspconfig'), {
--   on_attach = on_attach,
-- })
