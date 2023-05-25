return require("packer").startup(function()
	-- Packer can manage itself as an optional plugin
	use({ "wbthomason/packer.nvim", opt = true })

	-- Color scheme
	use({ "morhetz/gruvbox" })
	use({ "projekt0n/github-nvim-theme" })
	use({ "sainnhe/gruvbox-material" })
	use({ "kyazdani42/nvim-web-devicons" })

	use({ "nvim-treesitter/nvim-treesitter", run = ":TSUpdate", run = ":TSInstall go comment python" })
	use({ "nvim-treesitter/nvim-treesitter-context" })

	use({ "p00f/nvim-ts-rainbow" }) -- Rainbow brackets etc

	-- Fuzzy finder
	use({
		"nvim-telescope/telescope.nvim",
		requires = {
			{ "nvim-lua/popup.nvim" },
			{ "nvim-lua/plenary.nvim" },
			{ "nvim-telescope/telescope-symbols.nvim" },
			{ "cljoly/telescope-repo.nvim" },
		},
	})

	use({ "nvim-telescope/telescope-fzf-native.nvim", run = "make" })
	use({
		"nvim-telescope/telescope-frecency.nvim",
		requires = { "tami5/sql.nvim" },
		config = function()
			require("telescope").load_extension("frecency")
		end,
	})

	-- Navigation
	use({
		"akinsho/nvim-bufferline.lua",
		tag = "v2.*",
		requires = {
			"kyazdani42/nvim-web-devicons", -- optional, for file icon
		},
	})

	use({ "mvllow/modes.nvim" }) -- Line decoration for different modes

	use({
		"kyazdani42/nvim-tree.lua",
		requires = {
			"kyazdani42/nvim-web-devicons", -- optional, for file icon
		},
	})

	use({ "christoomey/vim-tmux-navigator" })

	use({
		"phaazon/hop.nvim",
		branch = "v1",
	})

	use({ "folke/zen-mode.nvim" })
	use({ "yamatsum/nvim-cursorline" })
	use({ "kevinhwang91/nvim-hlslens" })

	use({ "windwp/nvim-autopairs" })

	use({
		"goolord/alpha-nvim", -- Dashboard
		requires = { "kyazdani42/nvim-web-devicons" },
		config = function()
			require("alpha").setup(require("alpha.themes.startify").config)
		end,
	})

	-- LSP and completion
	-- It's important to have the LSP related plugins before the LSP config
	-- mason is required before lspconfig
	use({
		"williamboman/mason.nvim", -- LSP installer; must be added before lspconfig
		"williamboman/mason-lspconfig.nvim",
		"neovim/nvim-lspconfig",
	})

	use({
		"rmagatti/goto-preview",
		config = function()
			require("goto-preview").setup({})
		end,
	})

	use({ "ray-x/lsp_signature.nvim" })
	use({
		"hrsh7th/nvim-cmp", -- Autocompletion
		requires = {
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
			"hrsh7th/cmp-cmdline",
			"f3fora/cmp-spell",
			"andersevenrud/cmp-tmux",
		},
	})
	use({ "github/copilot.vim" })

	use({
		"j-hui/fidget.nvim",
		event = "BufReadPre",
		config = function()
			require("fidget").setup({})
		end,
	})
	use({ "jose-elias-alvarez/null-ls.nvim" })

	-- Git specifics
	use({ "kdheepak/lazygit.nvim" })

	use({
		"lewis6991/gitsigns.nvim",
		config = function()
			require("gitsigns").setup()
		end,
	})

	use({ "f-person/git-blame.nvim" })

	use({ "voldikss/vim-floaterm" })

	-- Developer workflow
	use({ "wakatime/vim-wakatime" })

	use({
		"folke/trouble.nvim",
		requires = "kyazdani42/nvim-web-devicons",
	})

	use({ "ianding1/leetcode.vim" })

	-- Easy comments
	use({
		"folke/todo-comments.nvim",
		requires = "nvim-lua/plenary.nvim",
	})

	use({
		"numToStr/Comment.nvim",
		config = function()
			require("Comment").setup()
		end,
	})

	-- Languages
	-- -- Go
	use({
		"ray-x/go.nvim",
		requires = "ray-x/guihua.lua",
	})

	-- -- Ruby
	use({ "vim-ruby/vim-ruby" })

	-- -- Python
	-- Python indent (follows the PEP8 style)
	use({ "Vimjas/vim-python-pep8-indent", ft = { "python" } })
	use({ "linux-cultist/venv-selector.nvim" })

	-- -- Other
	use({ "hashivim/vim-terraform" })
	use({ "lnl7/vim-nix" })
	use({ "towolf/vim-helm" })
	use({ "rust-lang/rust.vim" })

	-- -- lualine
	use({ "tjdevries/nlua.nvim" })

	--[[ (OPTIONAL): This is a suggested plugin to get better Lua syntax highlighting
   but it's not currently required ]]
	use({ "euclidianAce/BetterLua.vim" })

	-- Statusline
	use({ "nvim-lualine/lualine.nvim" })

	-- Zettlekasten
	use({ "mickael-menu/zk-nvim" })

	-- Other helpers
	use({
		"folke/which-key.nvim",
		config = function()
			require("which-key").setup({})
		end,
	})

	use({ "rhysd/vim-grammarous" })
	use({ "lukas-reineke/indent-blankline.nvim" })

	use({ "rcarriga/nvim-notify" })

	use({ "mhartington/formatter.nvim" })
	use({ "airblade/vim-rooter" })

	use({ "ryanoasis/vim-devicons" }) -- has to be the last loaded plugin
end)
