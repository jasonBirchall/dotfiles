require('lualine').setup {
  options = {
    icons_enabled = true,
    theme = 'auto',
    component_separators = { left = '', right = ''},
    section_separators = { left = '', right = ''},
    disabled_filetypes = {},
    always_divide_middle = true,
    globalstatus = false,
  },
  sections = {
    lualine_a = {
        'mode',
        icon = nil, -- displays icon in front of the component
        separator = nil, -- overwrites component_separators for component
        condition = nil, -- condition function, component is loaded when function returns true
        -- custom color for component in format
        -- color = {fg = '#rrggbb', bg= '#rrggbb', gui='style'}
        -- or highlight group
        -- color = "WarningMsg"
        color = nil
      },
    lualine_b = {'branch'},
    lualine_c = {
        {
            'filename',
            file_status = true, -- displays file status (readonly status, modified status)
            path = 1 -- 0 = just filename, 1 = relative path, 2 = absolute path
        }
    },
    lualine_x = {
        {
            'diff',
            colored = true, -- displays diff status in color if set to true
            -- all colors are in format #rrggbb
            color_added = nil, -- changes diff's added foreground color
            color_modified = nil, -- changes diff's modified foreground color
            color_removed = nil, -- changes diff's removed foreground color
            symbols = {added = '+', modified = '~', removed = '-'} -- changes diff symbols
        }
    },
    lualine_y = {
        {
            'filetype',
            colored = true
        }
    },
    lualine_z = {'location'}
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {'filename'},
    lualine_x = {'location'},
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {},
  extensions = {'nerdtree', 'toggleterm', 'quickfix', 'symbols-outline'}
}
