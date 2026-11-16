return {
  -- A review screen for changed code: a list of changed files on the left and
  -- a side-by-side diff on the right. Mostly for reading what an agent has just
  -- edited before committing it. The right-hand side is the real file, so
  -- fixes can be made in place.
  --
  --   <leader>gv   review uncommitted changes (press again to close)
  --   <leader>gV   history of the current file
  --   :DiffviewOpen main...HEAD   everything a branch changed
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles", "DiffviewFocusFiles" },
    keys = {
      {
        "<leader>gv",
        function()
          if require("diffview.lib").get_current_view() then
            vim.cmd("DiffviewClose")
          else
            vim.cmd("DiffviewOpen")
          end
        end,
        desc = "Review changes (Diffview)",
      },
      { "<leader>gV", "<cmd>DiffviewFileHistory %<cr>", desc = "File history (Diffview)" },
    },
    opts = {
      enhanced_diff_hl = true,
    },
  },
}
