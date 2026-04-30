#!/usr/bin/env bash
set -euo pipefail

# Simple multi-session concurrency stress harness for Surypus canonicalization
# Usage: ./scripts/concurrency_stress.sh <sessions> <command> <batch_size> [duration_sec]
#  - sessions: number of concurrent sessions to spawn
#  - command: canonicalize_all_batch or canonicalize_all
#  - batch_size: int, passed to the command if relevant
#  - duration: optional duration to run stress in seconds (default 60)

SESSIONS=${1:-4}
CMD=${2:-"canonicalize_all_batch"}
BATCH_SIZE=${3:-20}
DURATION=${4:-60}

HOST=${SURYPUS_DB_HOST:-localhost}
DB=${SURYPUS_DB_NAME:-surypus}
USER=${SURYPUS_DB_USER:-surypus}
export PGPASSWORD=${SURYPUS_DB_PASS:-''}

echo "Starting concurrency stress: sessions=$SESSIONS, cmd=$CMD, batch_size=$BATCH_SIZE, duration=${DURATION}s"

start_ts=$(date +%s)
end_ts=$((start_ts + DURATION))

PIDS=()
for i in $(seq 1 $SESSIONS); do
  if [[ "$CMD" == canonicalize_all_batch* ]]; then
    cmd_str="psql -h $HOST -U $USER -d $DB -c \"SELECT rbac.canonicalize_all_batch($BATCH_SIZE);\""
  else
    cmd_str="psql -h $HOST -U $USER -d $DB -c \"SELECT rbac.canonicalize_all();\""
  fi
  bash -lc "$cmd_str" >/tmp/rr.$i.log 2>&1 &
  PIDS+=($!)
done

echo "Launched ${#PIDS[@]} workers. Waiting for duration ${DURATION}s..."
sleep "$DURATION" || true

echo "Killing workers..."
for pid in "${PIDS[@]}"; do
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null || true
  fi
done
wait 2>/dev/null || true

echo "Stress run finished. Logs in /tmp/rr.*.log"
