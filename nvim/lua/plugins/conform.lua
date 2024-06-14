return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      python = { "isort", "black", "pylint", "flake8" },
      sh = { "shfmt" },
    },
  }
}
