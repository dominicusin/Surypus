#!/bin/bash
set -euo pipefail

STACK_OPTS=""
if [ -n "${SURYPUS_JOB_INTERVAL:-}" ]; then
  export SURYPUS_JOB_INTERVAL
fi

stack exec surypus-job-worker
