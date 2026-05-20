return {
  -- Seamless navigation between tmux panes and neovim splits.
  -- The tmux half is configured in tmux/tmux.conf (vim-tmux-navigator plugin).
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    keys = {
      { "<c-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Go to left window/pane" },
      { "<c-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Go to lower window/pane" },
      { "<c-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Go to upper window/pane" },
      { "<c-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Go to right window/pane" },
    },
  },
}
