return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/neotest-python",
      "nvim-neotest/nvim-nio",
      "nvim-treesitter/nvim-treesitter",
    },
    adapters = {
      ["neotest-python"] = {
        -- Force the use of Pytest
        runner = "pytest",
        -- Defer to Pytest's collection engine (respecting pyproject.toml)
        pytest_discover_instances = true,
        -- Override the gatekeeper to allow BDD file naming
        is_test_file = function(file_path)
          if file_path == nil then return false end
          local is_test = string.match(file_path, "test_.*%.py$")
            or string.match(file_path, ".*_test%.py$")
            or string.match(file_path, ".*_spec%.py$")
          return is_test ~= nil
        end,
      },
    },
  },
}
