set -g base-index 1
set -g default-terminal "screen-256color"

# remap prefix to Control + a
set -g prefix C-a
unbind C-b
bind C-a send-prefix

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

bind-key v split-window -h
bind-key s split-window -v

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

# THEME
set-option -g status on
set -g status-justify left
set -g status-bg default
set -g status-fg white
# set -g window-status-current-bg default
# set -g window-status-current-fg yellow
#set -g window-status-current-attr bold
set -g status-interval 10
set -g status-right-length 60
set -g status-left ''
set -g status-right '#[fg=yellow]#(~/.completions/tmux_kube.sh)#[default] #[fg=green]#(~/bin/ping_response.rb) #[fg=white] %H:%M:%S %d-%b-%y '

# visual notification of activity in other windows
setw -g monitor-activity on
set -g visual-activity on

# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect' # restore tmux sessions

# Other examples:
# set -g @plugin 'github_username/plugin_name'
# set -g @plugin 'git@github.com/user/plugin'
# set -g @plugin 'git@bitbucket.com/user/plugin'

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run -b '~/.tmux/plugins/tpm/tpm'
