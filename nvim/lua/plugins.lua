return require('packer').startup(function()
    
  -- Packer can manage itself as an optional plugin
  use {'wbthomason/packer.nvim', opt = true}

  -- Color scheme
  use { 'sainnhe/gruvbox-material' }
  use { 'morhetz/gruvbox' }
  use { 'kyazdani42/nvim-web-devicons' }

  use {'nvim-treesitter/nvim-treesitter', run = ':TSUpdate', run = ':TSInstall go'}

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

  -- LSP and completion
  use { 'neovim/nvim-lspconfig' }
  -- use { 'nvim-lua/completion-nvim' }

  use {'hrsh7th/nvim-compe'}

  -- Git specifics
  use { 'tpope/vim-fugitive' }
  use { 'tpope/vim-rhubarb' } -- use GBrowse to open in browser

  use {
      'lewis6991/gitsigns.nvim',
      config = function() require('gitsigns').setup() end
  }

  use {
      'TimUntersberger/neogit',
       config = function()
         require('neogit').setup {integrations = {diffview = true}}
       end
  }

  -- Developer workflow
  use { 'wakatime/vim-wakatime' }
  use {'voldikss/vim-browser-search'}

  -- Easy comments
  use { 'tpope/vim-commentary' }

  -- Languages
  use { 'fatih/vim-go' }
  use { 'buoto/gotests-vim' }

  use { 'vim-ruby/vim-ruby' }
  
  use { 'tjdevries/nlua.nvim' }

  -- Statusline
  use { 'hoob3rt/lualine.nvim' }

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

  use { 'ryanoasis/vim-devicons' } -- has to be the last loaded plugin
end)

