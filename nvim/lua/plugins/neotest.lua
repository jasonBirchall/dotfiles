return {
  "nvim-neotest/neotest",
  dependencies = {
    "neotest-python",
  },
  opts = {
    adapters = {
      ["neotest-python"] = {
        dap = { justMyCode = false },
        args = { "--log-level", "DEBUG" },
        runner = "pytest",
      },
    },
  },
}
