# This file should be sourced
# Just add `. .tools/interactive.sh` in ~/.bashrc for example

# Make sure MacOS doesn't complain about non-bash.
export BASH_SILENCE_DEPRECATION_WARNING=1

# Setup emacs
emacs=$(command -v emacs)
emacsclient=$(command -v emacsclient)

# Setup editor
if ! test -z "$emacs"
then
    if ! test -z $emacsclient
    then
        EDITOR="$emacsclient --quiet --alternate-editor="" --create-frame"
    else
        echo "Emacsclient is missing, using pure emacs ..." >&2
        EDITOR=$emacs
    fi
else
    echo "Emacs is missing, good luck..." >&2
    EDITOR=vi
fi

export EDITOR
alias e="\$EDITOR"

PAGER="bat -p"
export PAGER

se() {
    rg --vimgrep -p "$@" | $PAGER
}

alias bat="bat --style="changes,numbers""

alias sk="sk --ansi -i -c 'rg --color=always -i --line-number \"{}\"' --delimiter : --bind 'enter:execute-silent($EDITOR +{2} {1})'"

# Bind F1
bind '"\033OP":"sk\n"'

# Less colors
CLICOLOR=YesPlease
export CLICOLOR

HISTSIZE=10000
HISTFILESIZE=50000

# Bash specific options
if test "${0##*bash}" == ""
then
    shopt -s histverify
fi

# Git and kubectl auto-completion
GIT_COMPLETION_PATH="${HOME}/.tools/git-completion.bash"

if [ ! -f "${GIT_COMPLETION_PATH}" ]; then
  curl -s -o "${GIT_COMPLETION_PATH}" https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash
fi
source "${GIT_COMPLETION_PATH}"
source <(kubectl completion bash)

function kubectl() {
  # Change context
  if [[ "$1" == "context" ]]; then
    if [[ -z "$2" ]]; then
      echo "No context provided."
      return 1
    fi
    export KUBE_CTX="$2"
    unset KUBE_NS
    echo "Context set to $2"
    return 0
  fi

  if [[ "$1" == "unset-context" ]]; then
      command kubectl config unset current-context
      unset KUBE_CTX
      return 0
  fi

  # Change namespace
  if [[ "$1" == "namespace" ]]; then
    if [[ -z "$2" ]]; then
      echo "No namespace provided."
      return 1
    fi
    export KUBE_NS="$2"
    echo "Namespace set to $2"
    return 0
  fi

  if [[ -n "$KUBE_CTX" ]]; then
      local kube_ctx="--context=${KUBE_CTX}"
  fi

  if [[ -n "$KUBE_NS" ]]; then
      local kube_ns="--namespace=${KUBE_NS}"
  fi

  command kubectl ${kube_ctx} ${kube_ns} "$@"
}

kube_ps1() {
  local context="${KUBE_CTX}"
  if [[ -z "$context" ]]; then
    context="$(kubectl config current-context 2>/dev/null)"
  fi

  if [[ -z "$context" ]]; then
    echo ""
    return
  fi

  local ns="${KUBE_NS}"
  if [[ -z "$ns" ]]; then
    ns="$(kubectl config view --minify --output 'jsonpath={.contexts[?(@.name=="'$context'")].context.namespace}' 2>/dev/null)"
    [[ -z "$ns" ]] && ns="default"
  fi

  echo -n "${context}(${ns}) "
}

export PS1='$(kube_ps1)\w> '

function rename_terminal() {
  echo -ne "\033]0;$*\007"
}
