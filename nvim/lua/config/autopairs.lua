require('nvim-autopairs').setup({
  disable_filetype = { "TelescopePrompt" , "vim" },
  enable_check_bracket_line = false,
  check_ts = true,
  ignored_next_char = "[%w%.]", -- will ignore alphanumeric and `.` symbol
})

