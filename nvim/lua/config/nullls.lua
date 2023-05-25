local null_ls = require("null-ls")

-- register any number of sources simultaneously
local sources = {
	null_ls.builtins.code_actions.gitsigns,
	null_ls.builtins.code_actions.proselint,
	null_ls.builtins.code_actions.refactoring,
	null_ls.builtins.completion.spell,
	null_ls.builtins.diagnostics.pylint,
	null_ls.builtins.diagnostics.write_good,
	null_ls.builtins.formatting.autopep8.with({
		args = { "--max-line-length", "120", "-" },
		extra_args = { "--aggressive" },
	}),
	null_ls.builtins.formatting.isort,
	null_ls.builtins.formatting.terraform_fmt,
	null_ls.builtins.formatting.trim_whitespace,
	null_ls.builtins.hover.printenv,
}

null_ls.setup({ sources = sources })
