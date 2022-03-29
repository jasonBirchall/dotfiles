return require('packer').startup(function()
    
  -- Packer can manage itself as an optional plugin
  use {'wbthomason/packer.nvim', opt = true}

  -- Color scheme
  use { 'morhetz/gruvbox' }
  use { "projekt0n/github-nvim-theme" }
  use { 'sainnhe/gruvbox-material' }
  use { 'kyazdani42/nvim-web-devicons' }
  use { 'rebelot/kanagawa.nvim' }

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
    branch = 'v1',
  }

  use { 'petertriho/nvim-scrollbar' }

  use { "folke/zen-mode.nvim" }

  -- LSP and completion
  use { 'neovim/nvim-lspconfig' }

  use { 'ray-x/lsp_signature.nvim' }
  use { 'hrsh7th/nvim-compe' }
  use { 'github/copilot.vim' }

  -- Git specifics
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
  use { 'mfussenegger/nvim-dap' }
  use { 'rcarriga/nvim-dap-ui' }
  use { 'theHamsta/nvim-dap-virtual-text' }

  -- -- Ruby
  use { 'vim-ruby/vim-ruby' }
  
  use { 'tjdevries/nlua.nvim' }
  use { 'hashivim/vim-terraform' }
  use { 'lnl7/vim-nix' }

  -- Statusline
  use { 'nvim-lualine/lualine.nvim' }
  
  -- Snippets
  use { 'hrsh7th/vim-vsnip' }
  use { 'hrsh7th/vim-vsnip-integ' }
  use { 'golang/vscode-go' }

  -- Other helpers
  use {
    'folke/which-key.nvim',
    config = function() require("which-key").setup {} end
  }

  use { 'jiangmiao/auto-pairs' }

  use { 'lukas-reineke/indent-blankline.nvim' }
  -- use { 'airblade/vim-rooter' } -- Stay at the root of a project -- Update: Want to try without this for a while

  use { "rcarriga/nvim-notify" } -- Cool notifications

  use { 'ryanoasis/vim-devicons' } -- has to be the last loaded plugin
end)

