require"lualine".setup {
    options = {
        icons_enabled = true,
        theme = 'gruvbox-material',
        component_separators = {"", ""},
        section_separators = {"", ""},
        disabled_filetypes = {},
        globalstatus = false, -- enable in 0.7
    },
    sections = {
        lualine_a = {"mode"},
        lualine_b = {{"b:gitsigns_head", icon = ""}, "diff"},
        lualine_c = {
            {
                "filename",
                file_status = true,
                path = 1, -- show relativ path
                shorting_target = 40,
                symbols = {modified = "[]", readonly = " "}
            }
        },
        lualine_x = {
            {"diagnostics", sources = {"nvim_diagnostic"}},
            "fileformat", "filetype"
        },
        lualine_y = {"progress"},
        lualine_z = {"location"}
    },
    inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {"filename"},
        lualine_x = {"location"},
        lualine_y = {},
        lualine_z = {}
    },
    tabline = {},
    extensions = {"nvim-tree", "toggleterm", "quickfix", "symbols-outline"}
}

