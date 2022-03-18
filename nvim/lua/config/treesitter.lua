require'nvim-treesitter.configs'.setup {
  highlight = {
    enable = true,
    disable = {}
  },
  indent = {
    enable = true
  },
  autopairs = {
    enable = true
  },
  rainbow = {
    enable = true,
    extended_mode = true,
    max_file_lines = 1000, -- Do not enable for files with more than 1000 lines, int
  },
}
