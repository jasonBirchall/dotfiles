return {
  {
    "jose-elias-alvarez/null-ls.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = function(_, opts)
      local nls = require("null-ls")
      if type(opts.sources) == "table" then
        local null_ls = require("null-ls")
        vim.list_extend(opts.sources, {
          null_ls.builtins.formatting.terraform_fmt,
          null_ls.builtins.diagnostics.terraform_validate,
        })
        return {
          root_dir = require("null-ls.utils").root_pattern(".null-ls-root", ".neoconf.json", "Makefile", ".git"),
          sources = {
            nls.builtins.formatting.stylua,
            nls.builtins.formatting.shfmt,
            nls.builtins.diagnostics.flake8,
          },
        }
      end
      opts.sources = opts.sources or {}
      vim.list_extend(opts.sources, {
        nls.builtins.diagnostics.hadolint,
      })
    end,
    dependencies = {
      "mason.nvim",
      opts = function(_, opts)
        opts.ensure_installed = opts.ensure_installed or {}
        vim.list_extend(opts.ensure_installed, { "hadolint" })
      end,
    },
  },
}
