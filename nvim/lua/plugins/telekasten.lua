return {
  {
    "renerocksai/telekasten.nvim",
    dependencies = {'nvim-telescope/telescope.nvim'},
    opts = {
      home = vim.fn.expand("~/Documents/workarea/zettelkasten"),
    },
  },
}
