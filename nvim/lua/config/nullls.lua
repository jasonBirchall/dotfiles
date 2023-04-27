local null_ls = require("null-ls")

null_ls.setup({
	sources = {
		null_ls.builtins.formatting.autopep8,
		null_ls.builtins.completion.spell,
		null_ls.builtins.code_actions.refactoring,
		null_ls.builtins.code_actions.shellcheck,
		null_ls.builtins.code_actions.proselint,
		null_ls.builtins.diagnostics.pylint,
	},
})
