# .bashrc

# Auto-completion
. /etc/bash_completion

source <(kubectl completion bash)

if [[ -d /etc/bash-completion.d/ ]]; then
  for file in /etc/bash_completion.d/*; do
    source "$file"
  done
fi

# Set env variables
export BROWSER=/usr/bin/firefox
export EDITOR=/usr/bin/vim
export GIT_EDITOR=${EDITOR}
export KOPS_STATE_STORE=s3://cloud-platform-kops-state
export KUBECONFIG=$HOME/.kube/config
export PATH=/usr/local/go/bin:$(go env GOPATH)/bin:/home/linuxbrew/.linuxbrew/bin:./.bundle/bin:$HOME:$HOME/.gem/bin:$PATH

# Set History configuration
# Only store unique commands in history, and disregard leading spaces
export HISTCONTROL=ignoreboth:erasedups

shopt -s histappend
export HISTSIZE= HISTFILESIZE= # Infinite history
export HISTIGNORE='ls:bg:fg:history:ps:htop:top' # Ignore certain commands
export HISTTIMEFORMAT='%F %T ' # Record timestamps
export PROMPT_COMMAND='history -a' # Immediately record history

# Aliases
# Add an alert alias for long running commands
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
# ruby alias
alias bi='bundle install --path .bundle/gems --binstubs .bundle/bin'
alias cdw='cd ~/Documents/workarea'
alias l='ls -CF'
alias la='ls -latr'
alias ll='ls -alF'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias live-1='KUBECONFIG=$HOME/.kube/config.live-1'
alias live-0='KUBECONFIG=$HOME/.kube/config.live-0'

alias htop="sudo docker run --rm -it --pid host json0/htop"

# Bash profiles
source ~/.bash_profile
