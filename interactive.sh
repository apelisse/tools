# This file should be sourced
# Just add `. .tools/interactive.sh` in ~/.bashrc for example

# Make sure MacOS doesn't complain about non-bash.
export BASH_SILENCE_DEPRECATION_WARNING=1

# Make sure venv never changes your prompt.
export VIRTUAL_ENV_DISABLE_PROMPT=1

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

se() {
    rg --vimgrep -p "$@" | ${PAGER:-less}
}

alias bat="bat --style="changes,numbers""
LESS=FXR
export LESS

alias skf="sk --ansi -i -c 'rg --color=always -i --line-number \"{}\"' --delimiter : --bind 'enter:execute-silent($EDITOR +{2} {1})'"

# Less colors
CLICOLOR=YesPlease
export CLICOLOR

command -v mcfly >/dev/null && eval "$(mcfly init bash)"

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

# Load kubectl bash completion and bind it to the wrapper name
if command -v kubectl >/dev/null 2>&1; then
  # Cache the completion script to a regular file to avoid
  # macOS/bash3 quirks with process substitution not defining functions.
  KUBECTL_COMPLETION_CACHE="${HOME}/.tools/kubectl-completion.bash"
  # Generate or refresh cache file if missing or empty
  if [ ! -s "$KUBECTL_COMPLETION_CACHE" ]; then
    command kubectl completion bash > "$KUBECTL_COMPLETION_CACHE" 2>/dev/null || true
  fi
  # Source the cached script; fall back to process substitution if needed
  if [ -s "$KUBECTL_COMPLETION_CACHE" ]; then
    source "$KUBECTL_COMPLETION_CACHE"
  else
    # Last resort
    source <(command kubectl completion bash)
  fi
  # Explicitly (re)bind the completion to the wrapper name
  complete -o default -F __start_kubectl kubectl
fi

KUBECONFIG="$(kube-session --init)"
export KUBECONFIG
# Keep kube-config read-only to prevent accidental changes.
chmod a-w "${HOME}/.kube/config"

kube_ps1() {
  local context
  context="$(kubectl config current-context 2>/dev/null)"
  if [[ -z "$context" ]]; then
    echo ""
    return
  fi

  local ns
  ns="$(kubectl config view --minify --output "jsonpath={.contexts[?(@.name==\"${context}\")].context.namespace}" 2>/dev/null)"
  [[ -z "$ns" ]] && ns="default"

  echo -n "${context}(${ns}) "
}

export PS1='$(kube_ps1)\w> '

function rename_terminal() {
  echo -ne "\033]0;$*\007"
}
