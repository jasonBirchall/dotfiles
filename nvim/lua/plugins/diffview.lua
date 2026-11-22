return {
  -- A review screen for changed code: a list of changed files on the left and
  -- a side-by-side diff on the right. Mostly for reading what an agent has just
  -- edited before committing it. The right-hand side is the real file, so
  -- fixes can be made in place.
  --
  --   <leader>gv   review uncommitted changes (press again to close)
  --   <leader>gV   history of the current file
  --   :DiffviewOpen main...HEAD   everything a branch changed
  --
  -- Opened from lazygit (X, see lazygit/config.yml) nvim exists only to show
  -- the diff, so there q, :q and :wq leave nvim altogether instead of closing
  -- one window of several. lazygit asks for that by starting nvim with
  -- g:diffview_quit_all set; an ordinary nvim session is not affected.
  -- Unsaved edits still stop the quit, as :qa always does.
  {
    "sindrets/diffview.nvim",
    init = function()
      if vim.g.diffview_quit_all ~= 1 then
        return
      end
      vim.keymap.set("n", "q", "<cmd>qa<cr>", { nowait = true, desc = "Quit the review" })
      for from, to in pairs({ q = "qa", wq = "wqa" }) do
        vim.cmd(
          ("cnoreabbrev <expr> %s (getcmdtype() == ':' && getcmdline() ==# '%s') ? '%s' : '%s'"):format(from, from, to, from)
        )
      end
    end,
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
