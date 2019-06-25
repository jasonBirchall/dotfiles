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
BROWSER=/usr/bin/firefox
EDITOR=/usr/bin/vim
GIT_EDITOR=${EDITOR}
KOPS_STATE_STORE=s3://cloud-platform-kops-state
KUBECONFIG=$HOME/.kube/config
PATH=/usr/local/go/bin:$(go env GOPATH)/bin:/home/linuxbrew/.linuxbrew/bin:$PATH

# Set History configuration
# Only store unique commands in history, and disregard leading spaces
export HISTCONTROL=ignoreboth:erasedups

shopt -s histappend
HISTSIZE=10000000
HISTFILESIZE=20000000
HISTIGNORE='ls:bg:fg:history:ps:htop:top' # Ignore certain commands
HISTTIMEFORMAT='%F %T ' # Record timestamps
PROMPT_COMMAND='history -a' # Immediately record history

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

alias live-1='KUBECONFIG=$HOME/.kube/config.live-1'
alias live-0='KUBECONFIG=$HOME/.kube/config.live-0'

# Bash profiles
source ~/.bash_profile
