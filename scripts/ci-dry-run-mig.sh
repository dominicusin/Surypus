#!/usr/bin/env bash
set -euo pipefail

echo "Dry-run: validating generated migrations (no DB)"
errors=0
for f in sql/migrations/V*.sql; do
  if [[ -s "$f" ]]; then
    echo "OK: $f is non-empty"
  else
    echo "ERR: $f is empty"; errors=$((errors+1))
  fi
done
if [ "$errors" -ne 0 ]; then
  echo "Dry-run failed with $errors error(s)."
  exit 1
fi
echo "Dry-run completed successfully."
