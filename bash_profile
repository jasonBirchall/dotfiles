NORMAL="\[\033[00m\]"
BLUE="\[\033[01;34m\]"
YELLOW="\[\e[1;33m\]"
GREEN="\[\e[1;32m\]"

source ~/.completions/kube_prompt.sh
source ~/.completions/git_prompt.sh
source ~/.bashrc

# Will output the user host then k8s cluster, followed by the working dir and git status
export PS1="${NORMAL}\u@${NORMAL}\h ${GREEN}\A ${NORMAL}\$(__kube_ps1) ${BLUE}\w ${GREEN}\$(git_prompt)${NORMAL}\$ "

