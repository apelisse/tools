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

HISTSIZE=10000
HISTFILESIZE=50000

# Use a per-shell kubeconfig overlay so kubectl state stays local to
# each terminal while still reading from the main config.
mkdir -p "${HOME}/.kube/sessions"
cleanup_kube_sessions() {
  local dir="${HOME}/.kube/sessions"
  local file pid
  local nullglob_set=0

  if shopt -q nullglob; then
    nullglob_set=1
  fi

  shopt -s nullglob
  for file in "${dir}"/session-*.yaml; do
    pid="${file##*/session-}"
    pid="${pid%.yaml}"
    [[ "${pid}" =~ ^[0-9]+$ ]] || continue
    if ! kill -0 "${pid}" 2>/dev/null; then
      rm -f -- "${file}"
    fi
  done

  if [[ ${nullglob_set} -eq 0 ]]; then
    shopt -u nullglob
  fi
}

cleanup_kube_sessions
KUBE_SESSION_KUBECONFIG="${HOME}/.kube/sessions/session-$$.yaml"
touch "${KUBE_SESSION_KUBECONFIG}"
KUBE_BASE_CONFIG="${KUBECONFIG:-${HOME}/.kube/config}"
KUBECONFIG="${KUBE_SESSION_KUBECONFIG}"
export KUBE_SESSION_KUBECONFIG KUBE_BASE_CONFIG KUBECONFIG
trap 'rm -f -- "${KUBE_SESSION_KUBECONFIG}"' EXIT

# Bash specific options
if test "${0##*bash}" == ""
then
    shopt -s histverify
fi

function kubectl() {
  # Change context and optionally namespace
  if [[ "$1" == "context" ]]; then
    if [[ -z "$2" ]]; then
      echo "No context provided."
      return 1
    fi
    local ctx="$2"
    command kubectl config view --minify --raw --context "${ctx}" --kubeconfig="${KUBE_BASE_CONFIG}" >"${KUBE_SESSION_KUBECONFIG}"
    if [[ -n "$3" ]]; then
      local ns="$3"
      kubectl namespace "${ns}"
      echo "Context set to $ctx and namespace set to $ns"
    else
      echo "Context set to $ctx"
    fi
    return 0
  fi

  if [[ "$1" == "unset-context" ]]; then
    command kubectl config unset current-context --kubeconfig="${KUBE_SESSION_KUBECONFIG}"
    return 0
  fi

  if [[ "$1" == "namespace" ]]; then
    if [[ -z "$2" ]]; then
      echo "No namespace provided."
      return 1
    fi
    local ns="$2"
    command kubectl config set-context --current --namespace="${ns}" --kubeconfig="${KUBE_SESSION_KUBECONFIG}"
    echo "Namespace set to $ns"
    return 0
  fi

  command kubectl "$@"
}

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

kube_ps1() {
  local context
  context="$(kubectl config current-context 2>/dev/null)"
  if [[ -z "$context" && -n "${KUBE_CTX:-}" ]]; then
    context="${KUBE_CTX}"
  fi
  if [[ -z "$context" ]]; then
    echo ""
    return
  fi

  local ns
  ns="$(kubectl config view --minify --output "jsonpath={.contexts[?(@.name==\"${context}\")].context.namespace}" 2>/dev/null)"
  if [[ -z "$ns" && -n "${KUBE_NS:-}" ]]; then
    ns="${KUBE_NS}"
  fi
  [[ -z "$ns" ]] && ns="default"

  echo -n "${context}(${ns}) "
}

export PS1='$(kube_ps1)\w> '

function rename_terminal() {
  echo -ne "\033]0;$*\007"
}
