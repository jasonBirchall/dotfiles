return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/neotest-python",
      "nvim-neotest/neotest-plenary",
    },
    opts = {
      adapters = {
        ["neotest-plenary"] = {},
        ["neotest-python"] = {
          -- Here you can specify the settings for the adapter, i.e.
          dap = {
            console = "integratedTerminal",
            stopOnEntry = false,  -- which is the default(false)
            subProcess = false,  -- see config/testing.lua
            openUIOnEntry = false,
            justMyCode = false,
          },
          runner = "pytest",
          args = { "-vv", "-s" },
          -- args = { "--log-level", "DEBUG" },
          -- python = vim.g.python_host_prog,
        },
      },
    },
  },
}
