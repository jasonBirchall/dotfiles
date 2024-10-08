return {
  "linux-cultist/venv-selector.nvim",
  opts = {
    settings = {
      options = {
        notify_user_on_venv_activation = true,
        pipenv_path = "~/.local/share/virtualenvs",
        pipenv_auto_detection = true, -- Automatically detect Pipenv files
        auto_activate = true, -- Automatically activate the Pipenv environment
      },
    },
  },
}
