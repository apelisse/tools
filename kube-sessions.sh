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

# We treat our kube-config as a museum, never modify it.
chmod a-w "${HOME}/.kube/config"

cleanup_kube_sessions
KUBE_SESSION_KUBECONFIG="${HOME}/.kube/sessions/session-$$.yaml"
KUBE_BASE_CONFIG="${KUBECONFIG:-${HOME}/.kube/config}"
KUBECONFIG="${KUBE_SESSION_KUBECONFIG}:${KUBE_BASE_CONFIG}"
export KUBECONFIG


kctx() {
  if [[ -z "$1" ]]; then
    rm -f -- "$KUBE_SESSION_KUBECONFIG"
    : >"$KUBE_SESSION_KUBECONFIG"
    return
  fi
  command kubectl config view --minify --raw --context "$1" \
    --kubeconfig="$KUBE_BASE_CONFIG" >"$KUBE_SESSION_KUBECONFIG"

  if [[ -n "$2" ]]; then
    kns "$2"
  fi
}

kns() {
  command kubectl config set-context --current --namespace="$1" \
    --kubeconfig="$KUBE_SESSION_KUBECONFIG"
}
