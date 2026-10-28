#!/usr/bin/env bash
# NInfer launch profile: 128K context (device pool 4096, host KV 8192 MiB)
#
# Usage:
#   bash tools/profiles/start-128k.sh [--model /abs/path.ninfer] [--port 8091]
#
# Environment overrides:
#   NINFER_MODEL     model artifact path   (default: /h/Models/LLM/bonsai2_27b_ternary_ptq1_native_mtp.ninfer)
#   NINFER_PORT      listen port           (default: 8091)
#   NINFER_RUN_DIR   directory with ninfer-serve.exe (default: <repo>/.deps/build-89/apps/Release)
#   NINFER_LOG_DIR   log directory         (default: <repo>/.temp/ninfer-analysis/logs/run)
#   NINFER_ATTEMPTS  startup attempts      (default: 5)
#
# The script kills any running ninfer-serve.exe first, retries the reservation a few
# times (VA squeeze is unstable under desktop load), then waits for /v1/models.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODEL="${NINFER_MODEL:-/h/Models/LLM/bonsai2_27b_ternary_ptq1_native_mtp.ninfer}"
PORT="${NINFER_PORT:-8091}"
RUN_DIR="${NINFER_RUN_DIR:-$ROOT/.deps/build-89/apps/Release}"
LOG_DIR="${NINFER_LOG_DIR:-$ROOT/.temp/ninfer-analysis/logs/run}"
ATTEMPTS="${NINFER_ATTEMPTS:-5}"
LOG="$LOG_DIR/engine-PROFILE.log"

while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

command -v curl.exe >/dev/null 2>&1 && CURL=curl.exe || CURL=curl
if [ ! -x "$RUN_DIR/ninfer-serve.exe" ]; then
  echo "engine not found: $RUN_DIR/ninfer-serve.exe" >&2
  echo "build it first (see docs/01-部署与编译总白皮书.md) or set NINFER_RUN_DIR" >&2
  exit 1
fi
mkdir -p "$LOG_DIR"

taskkill //F //IM ninfer-serve.exe >/dev/null 2>&1 || true
sleep 6

for attempt in $(seq 1 "$ATTEMPTS"); do
  (
    cd "$RUN_DIR" || exit 1
    CUDA_MODULE_LOADING=LAZY \
    NINFER_VA_RETRY_COUNT=120 \
    NINFER_VA_RETRY_MS=250 \
    NINFER_KV_WINDOW=4096 \
    NINFER_HOST_PAGEABLE=1 \
    NINFER_KV_REUSE_HOSTBACKED=1 \
    NINFER_TERNARY_KVMEM_SCORE=0 \
    NINFER_KV_RETRIEVE=8 \
    ./ninfer-serve.exe "$MODEL" \
      --host 127.0.0.1 --port "$PORT" --model-id ninfer-local \
      --max-context 131072 \
      --kv-capacity 4096 \
      --kv-dtype rk4v4-e8 \
      --host-kv-mib 8192 \
      --prefill-chunk 512 \
      --max-concurrency 1 \
      --max-shared-prefixes 0 \
      --device-state-slots 1 \
      --host-state-slots 4 \
      --max-private-continuations 8 \
      --max-long-anchors-per-continuation 2 \
      --auto-long-anchors \
      --derive-session-keys \
      --no-cuda-graph \
      --gdn-state-fp16 \
      --spec mtp --draft-tokens 1 --mtp-attention-window 8 \
      --device-profile off \
      --default-max-tokens 32768 \
      > "$LOG.$attempt" 2>&1 &
  )
  sleep 40
  if "$CURL" -s -m 2 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/v1/models" 2>/dev/null | grep -q 200; then
    echo "ATTEMPT $attempt OK"
    grep -aE 'capacity \|' "$LOG.$attempt" | tail -1 | cut -c1-170
    nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader
    exit 0
  fi
  echo "attempt $attempt failed"
  taskkill //F //IM ninfer-serve.exe >/dev/null 2>&1 || true
  sleep 6
done

echo "LOOP_FAILED: engine did not reach /v1/models on port $PORT" >&2
exit 1
