return require('packer').startup(function()
    
  -- Packer can manage itself as an optional plugin
  use {'wbthomason/packer.nvim', opt = true}

  -- Color scheme
  use { 'sainnhe/gruvbox-material' }

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

  -- LSP and completion
  use { 'neovim/nvim-lspconfig' }
  use { 'nvim-lua/completion-nvim' }

  -- Lua development
  use { 'tjdevries/nlua.nvim' }

  -- Git specifics
  use { 'tpope/vim-fugitive' }
  use { 'tpope/vim-rhubarb' } -- use GBrowse to open in browser

  use {
      'lewis6991/gitsigns.nvim',
      config = function() require('gitsigns').setup() end
  }

  -- Wakatime for metrics
  use { 'wakatime/vim-wakatime' }

  -- Vim tmux navigator
  use { 'christoomey/vim-tmux-navigator' }

  -- Easy comments
  use { 'tpope/vim-commentary' }

  -- Languages
  use { 'fatih/vim-go' }

  use { 'vim-ruby/vim-ruby' }
  
  -- Statusline
  use {
    'hoob3rt/lualine.nvim',
    requires = {'kyazdani42/nvim-web-devicons', opt = true}, {'ryanoasis/vim-devicons', opt = true}
  }

  -- Other helpers
  use {
    'folke/which-key.nvim',
    config = function() require("which-key").setup {} end
  }

  use { 'jiangmiao/auto-pairs' }

  use { 'tpope/vim-surround' }
end)

