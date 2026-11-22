return {
  -- add gruvbox
  --
  -- The diff colours are overridden. gruvbox.nvim's own are bright blocks
  -- (olive #62693e for added lines, #722529 for removed, solid yellow for the
  -- changed words) and the syntax colours on top of them are hard to read,
  -- most of all in Diffview. These are the same tints lazygit's delta uses
  -- (lazygit/config.yml): gruvbox red / green / blue blended into the
  -- background, about 15% for a line and 35% for the changed words, with the
  -- syntax colours left alone.
  {
    "ellisonleao/gruvbox.nvim",
    opts = {
      overrides = {
        DiffAdd = { bg = "#3e3e28" }, -- added line
        DiffDelete = { bg = "#482d2a" }, -- removed line
        DiffChange = { bg = "#363b39" }, -- line with a change in it
        -- the changed words on that line. fg is cleared as well: overrides
        -- are merged into the theme's entry, whose dark fg (meant for the
        -- yellow block) would otherwise stay and vanish into this background.
        DiffText = { bg = "#48544f", fg = "NONE" },
      },
    },
  },

  -- Configure LazyVim to load gruvbox
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },

  {
    "simrat39/symbols-outline.nvim",
    cmd = "SymbolsOutline",
    keys = { { "<leader>cs", "<cmd>SymbolsOutline<cr>", desc = "Symbols Outline" } },
    config = true,
  },
}
