require('telescope').load_extension('gh')

require("telescope").setup {
  pickers = {
    -- Your special builtin config goes in here
    buffers = {
      sort_lastused = true,
      theme = "dropdown",
      previewer = true,
    },
    find_files = {
      theme = "dropdown"
    }
  },
}