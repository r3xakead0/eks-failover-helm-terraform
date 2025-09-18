#!/usr/bin/env bash
set -Eeuo pipefail

# cleanup-ns.sh
# Limpia recursos de un namespace y elimina finalizers en EKS (multi-región/contextos).
# Por defecto actúa sobre los contextos 'primary' y 'secondary' y el namespace 'demo'.
# Requiere: kubectl, python (para editar JSON); jq opcional.

usage() {
  cat <<'USAGE'
Uso:
  cleanup-ns.sh [-n NAMESPACE] [--primary-context CTX] [--secondary-context CTX]
                [--skip-primary] [--skip-secondary]
                [--service-name NAME] [--deployment-name NAME] [--configmap-name NAME]

Por defecto:
  NAMESPACE=demo
  PRIMARY_CONTEXT=primary
  SECONDARY_CONTEXT=secondary
  SERVICE_NAME=web
  DEPLOYMENT_NAME=web
  CONFIGMAP_NAME=web-config

Ejemplos:
  ./cleanup-ns.sh
  ./cleanup-ns.sh -n demo --primary-context eks-us-east-1 --secondary-context eks-us-east-2
  ./cleanup-ns.sh --skip-secondary
USAGE
}

NAMESPACE="demo"
PRIMARY_CONTEXT="primary"
SECONDARY_CONTEXT="secondary"
DO_PRIMARY=1
DO_SECONDARY=1
SERVICE_NAME="web"
DEPLOYMENT_NAME="web"
CONFIGMAP_NAME="web-config"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NAMESPACE="$2"; shift 2;;
    --primary-context) PRIMARY_CONTEXT="$2"; shift 2;;
    --secondary-context) SECONDARY_CONTEXT="$2"; shift 2;;
    --skip-primary) DO_PRIMARY=0; shift;;
    --skip-secondary) DO_SECONDARY=0; shift;;
    --service-name) SERVICE_NAME="$2"; shift 2;;
    --deployment-name) DEPLOYMENT_NAME="$2"; shift 2;;
    --configmap-name) CONFIGMAP_NAME="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Argumento no reconocido: $1"; usage; exit 1;;
  esac
done

log() { echo -e "[$(date +'%H:%M:%S')] $*"; }
warn() { echo -e "[$(date +'%H:%M:%S')] [WARN] $*" >&2; }
err() { echo -e "[$(date +'%H:%M:%S')] [ERR ] $*" >&2; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

finalize_ns() {
  local CTX="$1"
  local NS="$2"
  local TMP_JSON
  TMP_JSON="$(mktemp)"
  trap 'rm -f "$TMP_JSON" "${TMP_JSON}.out" || true' RETURN

  if ! kubectl --context "$CTX" get ns "$NS" >/dev/null 2>&1; then
    warn "Namespace '$NS' no existe en contexto '$CTX' — nada que hacer."
    return 0
  fi

  log "[$CTX] Eliminando recursos en ns '$NS' (sin esperar)"
  kubectl --context "$CTX" -n "$NS" delete svc "$SERVICE_NAME" --wait=false 2>/dev/null || true
  kubectl --context "$CTX" -n "$NS" delete deploy "$DEPLOYMENT_NAME" --wait=false 2>/dev/null || true
  kubectl --context "$CTX" -n "$NS" delete configmap "$CONFIGMAP_NAME" --wait=false 2>/dev/null || true

  log "[$CTX] Quitando finalizers de recursos comunes"
  kubectl --context "$CTX" -n "$NS" patch svc "$SERVICE_NAME" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
  kubectl --context "$CTX" -n "$NS" patch deployment "$DEPLOYMENT_NAME" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
  kubectl --context "$CTX" -n "$NS" patch configmap "$CONFIGMAP_NAME" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true

  log "[$CTX] Eliminando finalizers del namespace '$NS' mediante /finalize"
  if ! kubectl --context "$CTX" get ns "$NS" -o json > "$TMP_JSON"; then
    warn "No pude obtener JSON del namespace en '$CTX'; saltando finalize."
    return 0
  fi

  if have_cmd jq; then
    jq 'del(.spec.finalizers)' "$TMP_JSON" > "${TMP_JSON}.out"
  else
    python - "$TMP_JSON" > "${TMP_JSON}.out" <<'PY'
import sys, json
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
if isinstance(data, dict) and 'spec' in data and 'finalizers' in data['spec']:
    data['spec'].pop('finalizers', None)
print(json.dumps(data))
PY
  fi

  # Aplica el finalize
  if kubectl --context "$CTX" replace --raw "/api/v1/namespaces/${NS}/finalize" -f "${TMP_JSON}.out" >/dev/null 2>&1; then
    log "[$CTX] Finalize enviado para ns '$NS'."
  else
    warn "[$CTX] Falló el finalize (puede ya estar eliminado)."
  fi

  # Verifica
  if kubectl --context "$CTX" get ns "$NS" >/dev/null 2>&1; then
    warn "[$CTX] El ns '$NS' aún existe (puede tardar unos segundos)."
  else
    log "[$CTX] Namespace '$NS' eliminado."
  fi
}

if [[ "$DO_PRIMARY" -eq 1 ]]; then
  log "Iniciando limpieza en contexto PRIMARY='$PRIMARY_CONTEXT' ns='$NAMESPACE'"
  finalize_ns "$PRIMARY_CONTEXT" "$NAMESPACE" || true
fi

if [[ "$DO_SECONDARY" -eq 1 ]]; then
  log "Iniciando limpieza en contexto SECONDARY='$SECONDARY_CONTEXT' ns='$NAMESPACE'"
  finalize_ns "$SECONDARY_CONTEXT" "$NAMESPACE" || true
fi

log "Hecho."
