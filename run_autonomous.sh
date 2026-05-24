#!/usr/bin/env bash
# run_autonomous.sh – автоматический цикл выполнения всех оставшихся фаз

REPO_ROOT="/home/domini/src/My/Surypus"
GSDSCRIPT="${REPO_ROOT}/.agent/get-shit-done/bin/gsd-tools.cjs"

# Helper to run a gsd-tools subcommand
gsd() {
  node "${GSDSCRIPT}" "$@"
}

# Load current state
gsd state load >/dev/null

# While there are unfinished phases
while true; do
  # Попытаться начать следующую фазу
  if ! gsd state begin-phase --auto >/dev/null 2>&1; then
    echo "Все фазы завершены."
    break
  fi

  # Выполнить план (обсуждение → план → исполнение) автоматически
  gsd state advance-plan --auto >/dev/null

  # Завершить фазу
  gsd state complete-phase --auto >/dev/null
done

# Финальная проверка и вывод статуса
gsd state load
gsd progress --json
