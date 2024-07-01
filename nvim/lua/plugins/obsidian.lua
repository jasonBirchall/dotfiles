return {
  "epwalsh/obsidian.nvim",
  version = "*",  -- recommended, use latest release instead of latest commit
  lazy = true,
  -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
  ft = "markdown",
  -- event = {
  --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
  --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/**.md"
  --   "BufReadPre " .. vim.fn.expand "~" .. "~/Documents/Documents/zettlr/**.md",
  --   "BufNewFile " .. vim.fn.expand "~" .. "~/Documents/Documents/zettlr/**.md",
  -- },
  dependencies = {
    -- Required.
    "nvim-lua/plenary.nvim",

    -- see below for full list of optional dependencies 👇
  },
  opts = {
    workspaces = {
      {
        name = "personal",
        path = "~/Documents/Documents/zettlr",
      },
    },
    new_notes_location = "Zettelkasten",
    daily_notes = {
      -- Optional, if you keep daily notes in a separate directory.
      folder = "Daily",
      -- Optional, if you want to automatically insert a template from your template directory like 'daily.md'
      template = "Template/🌱 Daily Growth Mindset Journal.mdk",
    },
    -- see below for full list of options 👇
  },
}
