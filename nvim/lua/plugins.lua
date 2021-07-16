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

  use { 'airblade/vim-gitgutter' }

  -- Wakatime for metrics
  use { 'wakatime/vim-wakatime' }

  -- Vim tmux navigator
  use { 'christoomey/vim-tmux-navigator' }

  -- Easy comments
  use { 'tpope/vim-commentary' }

  -- Languages
  use { 'fatih/vim-go' }

  use { 'vim-ruby/vim-ruby' }
  
  -- Formatting help
  use { 'jiangmiao/auto-pairs' }

  -- Statusline
  use {
    'hoob3rt/lualine.nvim',
    requires = {'kyazdani42/nvim-web-devicons', opt = true}, {'ryanoasis/vim-devicons', opt = true}
}

end)

