return {
  "nvim-neotest/neotest",
  dependencies = {
    "neotest-python",
    "nvim-neotest/nvim-nio"
  },
  opts = {
    adapters = {
      ["neotest-golang"] = {
        go_test_args = { "-v", "-race", "-count=1", "-timeout=60s" },
        dap_go_enabled = true,
      },
      ["neotest-python"] = {
        dap = { justMyCode = false },
        args = { "--log-level", "DEBUG" },
        runner = "pytest",
      },
    },
  status = { virtual_text = true },
  output = { open_on_run = true },
  quickfix = {
    open = function()
      if LazyVim.has("trouble.nvim") then
        require("trouble").open({ mode = "quickfix", focus = false })
      else
        vim.cmd("copen")
      end
    end,
  },
  },
}

