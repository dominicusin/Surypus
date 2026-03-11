#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SQL_FILES=()

shopt -s nullglob
for file in "$ROOT_DIR"/config/schema_Core_*.sql "$ROOT_DIR"/config/schema_PPObj*.sql; do
  [[ -f "$file" ]] && SQL_FILES+=("$file")
done
shopt -u nullglob

if [[ ${#SQL_FILES[@]} -eq 0 ]]; then
  echo "No target schema files found."
  exit 0
fi

printf '%s\n' "${SQL_FILES[@]}" | python3 - "$ROOT_DIR" <<'PY'
import collections
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1])
pattern = re.compile(
    r'\bCREATE\s+(?:OR\s+REPLACE\s+)?(TABLE|VIEW|FUNCTION|SEQUENCE|TRIGGER)\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:"?)([\w\.]+)(?:"?)',
    re.IGNORECASE,
)
names = collections.defaultdict(list)
for raw_path in sys.stdin:
    raw_path = raw_path.strip()
    if not raw_path:
        continue
    path = pathlib.Path(raw_path)
    if not path.is_absolute():
        path = ROOT / path
    text = path.read_text(encoding="utf-8")
    for match in pattern.finditer(text):
        key = match.group(2).lower()
        rel = str(path.relative_to(ROOT))
        names[key].append(rel)

duplicates = {name: occurs for name, occurs in names.items() if len(set(occurs)) > 1}
if duplicates:
    print("Найдены пересекающиеся объекты в схемах:")
    for name, files in sorted(duplicates.items()):
        print(f"  {name}:")
        for file in sorted(set(files)):
            print(f"    - {file}")
    sys.exit(1)

print("Проверка уникальности схем пройдена.")
PY
