# .bashrc

# Auto-completion
. /etc/bash_completion

source <(kubectl completion bash)
source <(skaffold completion bash)

if [[ -d /etc/bash-completion.d/ ]]; then
  for file in /etc/bash_completion.d/*; do
    source "$file"
  done
fi

# Set env variables
export BROWSER=/usr/bin/firefox
export EDITOR=/usr/bin/vim
export GIT_EDITOR=${EDITOR}
export KUBE_EDITOR=${EDITOR}
export KOPS_STATE_STORE=s3://cloud-platform-kops-state
export KUBECONFIG=$HOME/.kube/config
export JAVA_HOME=/usr/lib/jvm/jdk1.7.0_79
export PATH=/usr/share/bluej:$JAVA_HOME/bin:/bin:/home/linuxbrew/.linuxbrew/bin:./.bundle/bin:$HOME:$HOME/.gem/bin:/usr/local/go/bin:$PATH
export GOPATH=$HOME/go

# Set History configuration
# Only store unique commands in history, and disregard leading spaces
export HISTCONTROL=ignoreboth:erasedups

shopt -s histappend
export HISTSIZE= HISTFILESIZE= # Infinite history
export HISTIGNORE='ls:bg:fg:history:ps:htop:top' # Ignore certain commands
export HISTTIMEFORMAT='%F %T ' # Record timestamps
export PROMPT_COMMAND='history -a' # Immediately record history
export TERM='xterm-256color'
export RANGER_LOAD_DEFAULT_RC='FALSE' #Ranger file manager loads only my config
export REVIEW_BASE=master #Used in .gitconfig for quick diff

# Aliases
# Add an alert alias for long running commands
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
# ruby alias
alias bi='bundle install --path .bundle/gems --binstubs .bundle/bin'
alias cdd='cd ~/Documents/workarea/dotfiles'
alias cdw='cd ~/Documents/workarea'
alias cdi='cd ~/Documents/workarea/cloud-platform-infrastructure'
alias cdp='cd $GOPATH'
alias l='ls -CF'
alias la='ls -latr'
alias ll='ls -alF'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias home="xrandr --output DP-1 --auto --right-of eDP-1"

alias live-1='KUBECONFIG=$HOME/.kube/config.live-1'
alias live-0='KUBECONFIG=$HOME/.kube/config.live-0'
alias create-issue='cd $HOME/Documents/workarea/cloud-platform; hub issue create'
alias tf='terraform'
alias git='hub'
alias g='git'
alias gs='git status; git diff'
alias gd='git diff'
alias ga='git add'
alias gc='git commit'
alias k='kubectl'
alias cdgo='cd $GOPATH'

alias htop="docker run --rm -it --pid host json0/htop"
alias tmux="TERM=screen-256color-bce tmux"

