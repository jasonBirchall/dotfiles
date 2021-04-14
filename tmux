set -g base-index 1
set -g default-terminal "screen-256color"

# remap prefix to Control + a
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Use vim key bindings
set-option -g mode-keys vi
set-option -g status-keys vi

#Clipboard

# Automatically copy tmux selection to X clipboard
#bind -t vi-copy Enter copy-pipe "xclipboard -i -selection clipboard"

# For binding 'y' to copy and exiting selection mode
bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'xclip -sel clip -i'

# For binding 'Enter' to copy and not leave selection mode
bind-key -T copy-mode-vi Enter send-keys -X copy-pipe 'xclip -sel clip -i' '\;'  send -X clear-selection

# force a reload of the config file
unbind r
bind r source-file ~/.tmux.conf

# quick pane cycling
unbind ^A
bind ^A select-pane -t :.+

# Make mouse useful in copy mode
set -g mouse on

# Automatically set window title
set-window-option -g automatic-rename on
set-option -g set-titles on

#set -g default-terminal screen-256color
set -g status-keys vi
set -g history-limit 10000

setw -g monitor-activity on

bind-key v split-window -h -c "#{pane_current_path}"
bind-key s split-window -v -c "#{pane_current_path}"

bind-key J resize-pane -D 5
bind-key K resize-pane -U 5
bind-key H resize-pane -L 5
bind-key L resize-pane -R 5

bind-key M-j resize-pane -D
bind-key M-k resize-pane -U
bind-key M-h resize-pane -L
bind-key M-l resize-pane -R

# Vim style pane selection
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Use Alt-vim keys without prefix key to switch panes
bind -n M-h select-pane -L
bind -n M-j select-pane -D
bind -n M-k select-pane -U
bind -n M-l select-pane -R

# Use Alt-arrow keys without prefix key to switch panes
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Shift arrow to switch windows
bind -n S-Left  previous-window
bind -n S-Right next-window

# No delay for escape key press
set -sg escape-time 0

# Reload tmux config
bind r source-file ~/.tmux.conf

# Set status bar
set-option -g status on

# Status position
set-option -g status-position bottom

# Status update interval
set -g status-interval 10

# Basic status bar colors
set-option -g status-style bg=default,fg=white

# Left side of status bar
set-option -g status-left-length 40
set-option -g status-left "#[fg=brightwhite,bg=brightblack] #[fg=default,bg=default] "

# Window status
set-option -g window-status-format "#[fg=white,bg=brightblack] #I #[fg=white,bg=#363636] #W "
set-option -g window-status-current-format "#[fg=brightwhite,bg=green] #I #[fg=brightwhite,bg=blue] #W "
set-option -g window-status-separator " "

# Right side of status bar
set-option -g status-right-length 90
set-option -g status-right " #[fg=brightwhite,bg=#363636] %a, %d %b %H:%M #[fg=yellow,bg=black] #(~/.completions/tmux_kube.sh) "

# Pane border
set-option -g pane-border-style bg=default,fg=brightblack
set-option -g pane-active-border-style bg=default,fg=white

# Pane number indicator
set-option -g display-panes-colour brightblack
set-option -g display-panes-active-colour brightwhite

# Clock mode
set-option -g clock-mode-colour white
set-option -g clock-mode-style 24

# Message
set-option -g message-style bg=default,fg=default


# visual notification of activity in other windows
setw -g monitor-activity on
set -g visual-activity on

# Smart pane switching with awareness of Vim splits.
# See: https://github.com/christoomey/vim-tmux-navigator
is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
    | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"
bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
# bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
tmux_version='$(tmux -V | sed -En "s/^tmux ([0-9]+(.[0-9]+)?).*/\1/p")'
if-shell -b '[ "$(echo "$tmux_version < 3.0" | bc)" = 1 ]' \
    "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\'  'select-pane -l'"
if-shell -b '[ "$(echo "$tmux_version >= 3.0" | bc)" = 1 ]' \
    "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\\\'  'select-pane -l'"

bind-key -T copy-mode-vi 'C-h' select-pane -L
bind-key -T copy-mode-vi 'C-j' select-pane -D
bind-key -T copy-mode-vi 'C-k' select-pane -U
bind-key -T copy-mode-vi 'C-\' select-pane -l

# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect' # restore tmux sessions
set -g @plugin 'christoomey/vim-tmux-navigator'

# Other examples:
# set -g @plugin 'github_username/plugin_name'
# set -g @plugin 'git@github.com/user/plugin'
# set -g @plugin 'git@bitbucket.com/user/plugin'

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run -b '~/.tmux/plugins/tpm/tpm'
