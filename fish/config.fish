# Unset the default fish greeting text which messes up Zellij
set fish_greeting

# Environment variables - https://fishshell.com/docs/current/cmds/set.html
set -gx EDITOR nvim
set -gx GIT_EDITOR nvim
set -gx DOTFILES $HOME/Documents/workarea/dotfiles/
set -gx ZETTEL $HOME/Documents/workarea/zettelkasten/
set -gx WORKAREA $HOME/Documents/workarea/

# Config dir access
abbr -a -g cdd 'cd $DOTFILES'
abbr -a -g cdw 'cd $WORKAREA'

# Config git configuration
abbr -a -g lg lazygit
abbr -a -g g git

# Config EDITOR
abbr -a -g v nvim
abbr -a -g vim nvim
abbr -a -g r ranger

# Homebrew
abbr -a -g bru 'brew update && brew upgrade'

# Check if we're in an interactive shell
if status is-interactive

    # At this point, specify the Zellij config dir, so we can launch it manually if we want to
    export ZELLIJ_CONFIG_DIR=$HOME/.config/zellij

    # Check if our Terminal emulator is Ghostty
    if [ "$TERM" = xterm-ghostty ]
        # Launch zellij
        eval (zellij setup --generate-auto-start fish | string collect)
    end
end
