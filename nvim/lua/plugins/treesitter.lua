return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, { "ninja", "python", "rst", "toml" })
        vim.list_extend(opts.ensure_installed, { "html" })
        vim.list_extend(opts.ensure_installed, { "yaml" })
        vim.list_extend(opts.ensure_installed, { "dockerfile" })
        vim.list_extend(opts.ensure_installed, {
          "terraform",
          "hcl",
        })
        vim.list_extend(opts.ensure_installed, { "json", "json5", "jsonc" })
        vim.list_extend(opts.ensure_installed, {
          "go",
          "gomod",
          "gowork",
          "gosum",
        })
      end
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    init = function()
      -- disable rtp plugin, as we only need its queries for mini.ai
      -- In case other textobject modules are enabled, we will load them
      -- once nvim-treesitter is loaded
      require("lazy.core.loader").disable_rtp_plugin("nvim-treesitter-textobjects")
      load_textobjects = true
    end,
  },
}
