#!/everything/bin/bash
export PATH="$HOME/.local/bin:/nix/store/521dd0054ifhzmjfmpx9mz0hr7wh7sig-glibc-2.42-67-bin/sbin:/tmp/ldconfig-bin:/nix/store/bidxnrja5lch12iscmz8qf24v1b07gzr-ghc-9.10.3/bin:/guix/current/bin:/run/wrappers/bin:/usr/local/bin:$PATH"
export PYTHONPATH="$HOME/.local/lib/python3.14/site-packages:$PYTHONPATH"
# check-docs.sh
# Validate the Surypus documentation pipeline.
#
# Checks:
#   1. MkDocs site builds without warnings (--strict)
#   2. Module graph generates without errors
#   3. Documentation inventory is valid JSON
#   4. Coverage report is present
#   5. No generated file is manually modified (git check)
#
# Usage:
#   ./tools/documentation/check-docs.sh
#
set -euo pipefail

ERRORS=0

echo "=== Surypus Documentation Validation ==="
echo

echo "[1/5] MkDocs build (--strict)..."
if /home/domini/.local/bin/mkdocs build --strict 2>&1 | tail -5; then
    echo "✓ MkDocs build passed"
else
    echo "✗ MkDocs build failed"
    ERRORS=$((ERRORS+1))
fi
echo

echo "[2/5] Module graph..."
if ./tools/documentation/generate-module-graph.sh src docs/generated/graphs/modules.mmd >/dev/null 2>&1; then
    LINES=$(wc -l < docs/generated/graphs/modules.mmd)
    echo "✓ Module graph generated ($LINES lines)"
else
    echo "✗ Module graph generation failed"
    ERRORS=$((ERRORS+1))
fi
echo

echo "[3/5] Documentation inventory..."
if python3 tools/documentation/generate-inventory.py >/dev/null 2>&1; then
    if python3 -c "import json; json.load(open('docs/generated/inventory/modules.json')); print('✓ Valid modules.json')" 2>/dev/null; then
        echo "✓ Documentation inventory is valid JSON"
    else
        echo "✗ Invalid JSON in inventory"
        ERRORS=$((ERRORS+1))
    fi
else
    echo "✗ Inventory generation failed"
    ERRORS=$((ERRORS+1))
fi
echo

echo "[4/5] Coverage report..."
if [ -f docs/generated/inventory/coverage.json ]; then
    python3 -c "import json; c=json.load(open('docs/generated/inventory/coverage.json')); print(f\"✓ Coverage: {c['coverage']['percentage']}% ({c['coverage']['documented']}/{c['coverage']['modules']} modules)\")"
else
    echo "✗ coverage.json not found"
    ERRORS=$((ERRORS+1))
fi
echo

echo "[5/5] Generated files not manually modified..."
cd "$(dirname "$0")/../.."
if git diff --name-only -- docs/generated/ | grep -q .; then
    echo "✗ Generated files have manual modifications:"
    git diff --name-only -- docs/generated/
    ERRORS=$((ERRORS+1))
else
    echo "✓ Generated files are clean (no manual modifications)"
fi
echo

echo "=== Result: $ERRORS error(s) ==="
if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi
