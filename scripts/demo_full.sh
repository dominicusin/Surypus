#!/usr/bin/env bash
set -euo pipefail

echo "=== Building Surypus ==="
stack build

echo "=== Running API server (background) ==="
stack exec surypus &
SERVER_PID=$!
sleep 2

if command -v xdg-open >/dev/null 2>&1; then
	echo "Opening API UI at http://localhost:8080/api/v1 ..."
	xdg-open http://localhost:8080/api/v1
fi

echo "Demo running. Server PID: $SERVER_PID"
wait $SERVER_PID
