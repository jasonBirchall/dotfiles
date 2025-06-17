return {
  {
    "renerocksai/telekasten.nvim",
    dependencies = {'nvim-telescope/telescope.nvim', 'nvim-telescope/telescope-media-files.nvim'},
    opts = {
      home = vim.fn.expand("~/Documents/workarea/zettelkasten"),
      templates = vim.fn.expand("~/Documents/workarea/zettelkasten/templates"),
      template_new_note = vim.fn.expand("~/Documents/workarea/zettelkasten/templates/basenote.md")
    },
  },
}
