#!/usr/bin/env bash
set -euo pipefail

LOG_DIR=${LOG_DIR:-logs}
BUILD_LOG="$LOG_DIR/ci_run_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"

echo "CI run started at $(date)" | tee -a "$BUILD_LOG"

echo "Starting services..." | tee -a "$BUILD_LOG"
docker-compose up -d db api >>"$BUILD_LOG" 2>&1

echo "Waiting for DB readiness..." | tee -a "$BUILD_LOG"
for i in {1..60}; do
	if docker-compose exec -T db pg_isready -U surypus -d surypus >/dev/null 2>&1; then
		echo "DB is ready" | tee -a "$BUILD_LOG"
		break
	fi
	sleep 2
done

echo "Building project..." | tee -a "$BUILD_LOG"
STACK_ARGS=(--no-interactive)
stack build --no-run-tests "${STACK_ARGS[@]}" >>"$BUILD_LOG" 2>&1

echo "Running tests..." | tee -a "$BUILD_LOG"
stack test >>"$BUILD_LOG" 2>&1

echo "CI run completed. Logs:" | tee -a "$BUILD_LOG"
echo "$BUILD_LOG" | tee -a "$BUILD_LOG"
