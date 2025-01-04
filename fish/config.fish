# Unset the default fish greeting text which messes up Zellij
set fish_greeting
set fish_vi_key_bindings

# Check if we're in an interactive shell
if status is-interactive

    # At this point, specify the Zellij config dir, so we can launch it manually if we want to
    export ZELLIJ_CONFIG_DIR=$HOME/.config/zellij
    export EDITOR=nvim

    set -U fish_user_paths /usr/local/bin, $HOME/.cargo/bin $fish_user_paths

    # Check if our Terminal emulator is Ghostty
    if [ "$TERM" = xterm-ghostty ]
        # Launch zellij
        eval (zellij setup --generate-auto-start fish | string collect)
    end
end
