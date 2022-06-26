require("nvim-treesitter.configs").setup({
	ensure_installed = {
		"bash",
		"cmake",
		"dockerfile",
		"go",
		"hcl",
		"html",
		"java",
		"javascript",
		"json",
		"latex",
		"ledger",
		"lua",
		"python",
		"toml",
		"yaml",
		"markdown",
	}, -- one of "all", "maintained" (parsers with maintainers), or a list of languages
	highlight = {
		enable = true,
		disable = {},
	},
	indent = {
		enable = true,
	},
	autopairs = {
		enable = true,
	},
	rainbow = {
		enable = true,
		extended_mode = true,
		max_file_lines = 1000, -- Do not enable for files with more than 1000 lines, int
	},
})
