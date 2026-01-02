# This file should be sourced.

# Use a per-shell kubeconfig overlay so kubectl state stays local to
# each terminal while still reading from the main config.
mkdir -p "${HOME}/.kube/sessions"
cleanup_kube_sessions() {
  # Use sub-shell to not leak nullglob setting.
  (
    shopt -s nullglob
    for file in "${HOME}/.kube/sessions/session-*.yaml"; do
      pid="${file##*/session-}"
      pid="${pid%.yaml}"
      [[ "${pid}" =~ ^[0-9]+$ ]] || continue
      if ! kill -0 "${pid}" 2>/dev/null; then
        rm -f -- "${file}"
      fi
    done
  )
}

cleanup_kube_sessions
KUBE_SESSION_KUBECONFIG="${HOME}/.kube/sessions/session-$$.yaml"
KUBE_BASE_CONFIG="${KUBECONFIG:-${HOME}/.kube/config}"
KUBECONFIG="${KUBE_SESSION_KUBECONFIG}:${KUBE_BASE_CONFIG}"
export KUBECONFIG
trap 'rm -f -- "${KUBE_SESSION_KUBECONFIG}"' EXIT

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
