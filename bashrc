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
EDITOR=/usr/bin/vim
GIT_EDITOR=${EDITOR}
KOPS_STATE_STORE=s3://cloud-platform-kops-state
KUBECONFIG=$HOME/.kube/config
PATH=/usr/local/go/bin:$(go env GOPATH)/bin:/home/linuxbrew/.linuxbrew/bin:$PATH

# Only store unique commands in history, and disregard leading spaces
export HISTCONTROL=ignoreboth:erasedups

shopt -s histappend
HISTSIZE=100000
HISTFILESIZE=200000

# Aliases
# Add an alert alias for long running commands
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
alias cdw='cd ~/Documents/workarea'
alias l='ls -CF'
alias la='ls -latr'
alias ll='ls -alF'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Bash profiles
source ~/.bash_profile
