NORMAL="\[\033[00m\]"
BLUE="\[\033[01;34m\]"
YELLOW="\[\e[1;33m\]"
GREEN="\[\e[1;32m\]"

source ~/.kube_prompt.sh

export PS1="${NORMAL}\u@${NORMAL}\h ${GREEN}\A ${YELLOW}\$(__kube_ps1) ${BLUE}\w ${YELLOW}\$(__git_ps1 '(%s)') ${NORMAL}\$ "
#$(git branch 2>/dev/null | grep '^*' | colrm 1 2))
#export PS1="${debian_chroot:+($debian_chroot)}$GREEN\u$WHITE@$BLUE\h$WHITE\w\$ "
