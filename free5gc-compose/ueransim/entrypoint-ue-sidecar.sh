#!/bin/sh
set -eu

# Keep in-cluster traffic direct. Host proxy variables can leak into the
# container runtime and break calls to UPF/sidecar endpoints.
unset http_proxy HTTP_PROXY https_proxy HTTPS_PROXY all_proxy ALL_PROXY no_proxy NO_PROXY || true

SIDECAR_CONFIG="${SIDECAR_CONFIG:-./config/adaptive-qos-sidecar.yaml}"
SIDECAR_BIN="${SIDECAR_BIN:-./adaptive-qos-sidecar}"
DEMO_UI_BIN="${DEMO_UI_BIN:-./adaptive-qos-demo}"
DEMO_UI_LISTEN="${DEMO_UI_LISTEN:-0.0.0.0:8082}"
DEMO_UI_SIDECAR_BASE="${DEMO_UI_SIDECAR_BASE:-http://127.0.0.1:8081}"
DEMO_UI_UPF_BASE="${DEMO_UI_UPF_BASE:-http://upf:9082}"
CORE_READY_TIMEOUT="${CORE_READY_TIMEOUT:-90}"
CORE_READY_INTERVAL="${CORE_READY_INTERVAL:-2}"
UPF_HOST="${UPF_HOST:-upf}"
UPF_PORT="${UPF_PORT:-9082}"
SMF_HOST="${SMF_HOST:-smf}"
SMF_PORT="${SMF_PORT:-8000}"
AMF_HOST="${AMF_HOST:-amf}"
AMF_PORT="${AMF_PORT:-8000}"
UE_START_DELAY="${UE_START_DELAY:-15}"

wait_tcp() {
  host="$1"
  port="$2"
  timeout="$3"
  interval="$4"
  elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    if nc -z -w 2 "$host" "$port" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
  return 1
}

echo "[entrypoint] waiting for core tcp readiness: upf=${UPF_HOST}:${UPF_PORT} smf=${SMF_HOST}:${SMF_PORT} amf=${AMF_HOST}:${AMF_PORT}"
wait_tcp "$UPF_HOST" "$UPF_PORT" "$CORE_READY_TIMEOUT" "$CORE_READY_INTERVAL" || true
wait_tcp "$SMF_HOST" "$SMF_PORT" "$CORE_READY_TIMEOUT" "$CORE_READY_INTERVAL" || true
wait_tcp "$AMF_HOST" "$AMF_PORT" "$CORE_READY_TIMEOUT" "$CORE_READY_INTERVAL" || true
echo "[entrypoint] core reachable, sleeping ${UE_START_DELAY}s to avoid first-attach race"
sleep "$UE_START_DELAY"

if [ -x "$SIDECAR_BIN" ] && [ -f "$SIDECAR_CONFIG" ]; then
  echo "[entrypoint] starting sidecar: $SIDECAR_BIN -config $SIDECAR_CONFIG"
  "$SIDECAR_BIN" -config "$SIDECAR_CONFIG" &
fi

if [ -x "$DEMO_UI_BIN" ]; then
  echo "[entrypoint] starting demo ui: $DEMO_UI_BIN -listen $DEMO_UI_LISTEN"
  "$DEMO_UI_BIN" \
    -listen "$DEMO_UI_LISTEN" \
    -sidecar-base "$DEMO_UI_SIDECAR_BASE" \
    -upf-base "$DEMO_UI_UPF_BASE" &
fi

echo "[entrypoint] starting UE process: $*"
exec "$@"
