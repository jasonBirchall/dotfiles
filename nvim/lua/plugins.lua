return require('packer').startup(function()
    
  -- Packer can manage itself as an optional plugin
  use {'wbthomason/packer.nvim', opt = true}

  -- Color scheme
  use { 'morhetz/gruvbox' }
  use { "projekt0n/github-nvim-theme" }
  use { 'kyazdani42/nvim-web-devicons' }

  use {'nvim-treesitter/nvim-treesitter', run = ':TSUpdate', run = ':TSInstall go comment'}

  use {'p00f/nvim-ts-rainbow'} -- Rainbow brackets etc

  -- Fuzzy finder
  use {
      'nvim-telescope/telescope.nvim',
      requires = {{'nvim-lua/popup.nvim'}, {'nvim-lua/plenary.nvim'}}
  }

  use {'nvim-telescope/telescope-symbols.nvim'}
  use {'nvim-telescope/telescope-github.nvim'}
  use {'nvim-telescope/telescope-fzf-native.nvim', run = 'make'}
  use {
      'nvim-telescope/telescope-frecency.nvim',
      requires = {'tami5/sql.nvim'},
      config = function()
        require('telescope').load_extension('frecency')
      end
  }

  -- Navigation
  use {
      'preservim/nerdtree',
      requires = {'Xuyuanp/nerdtree-git-plugin'}
  }

  use { 'christoomey/vim-tmux-navigator' }

  use { "simeji/winresizer" }

  use {
    'phaazon/hop.nvim',
    as = 'hop',
    config = function()
      -- you can configure Hop the way you like here; see :h hop-config
      require'hop'.setup { keys = 'etovxqpdygfblzhckisuran' }
    end
  }

  use { 'petertriho/nvim-scrollbar' }

  -- LSP and completion
  use { 'neovim/nvim-lspconfig' }

  use { 'ray-x/lsp_signature.nvim' }
  use { 'hrsh7th/nvim-compe' }
  use { 'github/copilot.vim' }

  -- Git specifics
  use { 'tpope/vim-fugitive' }
  use { 'tpope/vim-rhubarb' } -- use GBrowse to open in browser

  use {
      'lewis6991/gitsigns.nvim',
      config = function() require('gitsigns').setup() end
  }

  use { 'f-person/git-blame.nvim' }

  use {
      'TimUntersberger/neogit',
       config = function()
         require('neogit').setup {
             integrations = {
                 diffview = true
             },
             auto_refresh = true,
             commit_popup = {
                 kind = "split",
             },
             disable_commit_confirmation = true,
         }
       end
  }
  use {'sindrets/diffview.nvim'}
  use {'voldikss/vim-floaterm'}

  -- Developer workflow
  use { 'wakatime/vim-wakatime' }
  use { 'voldikss/vim-browser-search' }

  use({
      "folke/persistence.nvim",
      event = "BufReadPre",
      module = "persistence",
      config = function() require("persistence").setup() end
  })

  use {
    'folke/trouble.nvim',
    requires = 'kyazdani42/nvim-web-devicons'
  }

  -- Easy comments
  use { 'tpope/vim-commentary' }

  -- Languages
  -- -- Go
  use { 'ray-x/go.nvim' }
  use { 'buoto/gotests-vim' }

  -- -- Ruby
  use { 'vim-ruby/vim-ruby' }
  
  use { 'tjdevries/nlua.nvim' }
  use { 'hashivim/vim-terraform' }
  use { 'lnl7/vim-nix' }

  -- Statusline
  use { 'hoob3rt/lualine.nvim' }
  
  -- Snippets
  use { 'hrsh7th/vim-vsnip' }
  use { 'hrsh7th/vim-vsnip-integ' }
  use { 'golang/vscode-go' }

  -- Other helpers
  use {
    'folke/which-key.nvim',
    config = function() require("which-key").setup {} end
  }

  use { 'troydm/zoomwintab.vim' }
  use { 'jiangmiao/auto-pairs' }

  use { 'tpope/vim-surround' }

  use { 'lukas-reineke/indent-blankline.nvim' }
  use {'airblade/vim-rooter'}

  use { 'tpope/vim-obsession' }

  use { 'hoschi/yode-nvim' }

  use { "rcarriga/nvim-notify" }

  use { 'ryanoasis/vim-devicons' } -- has to be the last loaded plugin
end)

