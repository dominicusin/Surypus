#!/usr/bin/env python3
"""generate-inventory.py — generate documentation inventory from Surypus src/.

Produces:
  docs/generated/inventory/modules.json
  docs/generated/inventory/coverage.json
  docs/generated/inventory/functions.json

Usage:
  python3 tools/documentation/generate-inventory.py
"""
import os
import re
import json
import glob

SRC_DIR = os.environ.get("SRC_DIR", "src")
OUT_DIR = os.environ.get("OUT_DIR", "docs/generated/inventory")
os.makedirs(OUT_DIR, exist_ok=True)

module_list = []
function_list = []

for root, _dirs, files in os.walk(SRC_DIR):
    for fname in sorted(files):
        if not fname.endswith(".hs"):
            continue
        fpath = os.path.join(root, fname)
        with open(fpath, encoding="utf-8", errors="replace") as f:
            content = f.read()
        # Extract module name
        m = re.search(r'^module\s+([A-Z][A-Za-z0-9.]*)', content, re.MULTILINE)
        if not m:
            continue
        mod_name = m.group(1)
        lines = content.splitlines()
        # Count haddock comments (lines starting with --)
        haddock = sum(1 for l in lines if l.strip().startswith("--"))
        # Count doctest examples (lines containing >>>)
        doctest = sum(1 for l in lines if ">>>" in l)
        # Exported symbols (lines starting with a capital letter after whitespace)
        exports = sorted(set(
            re.findall(r'^\s+([A-Z][A-Za-z0-9]*)', content, re.MULTILINE)
        ))
        # Functions: lines like "foo :: Type" or "foo = "
        funcs = re.findall(r'^\s*([a-z][a-zA-Z0-9]*)\s*::', content, re.MULTILINE)
        doc_funcs = sum(1 for l in lines if re.match(r'^\s*--\s*\S', l) and any(f in l for f in funcs))

        module_list.append({
            "module": mod_name,
            "file": fpath,
            "lines": len(lines),
            "exports": len(exports),
            "export_names": exports[:50],
            "haddock_comments": haddock,
            "doctest_examples": doctest,
            "functions": len(funcs),
            "documented_functions": doc_funcs,
        })
        for fn in funcs:
            function_list.append({
                "module": mod_name,
                "function": fn,
                "file": fpath,
            })

inventory = {
    "project": "Surypus",
    "version": "0.1.0.0",
    "generator": "surypus-codegen",
    "modules": module_list,
    "total_modules": len(module_list),
}

with open(os.path.join(OUT_DIR, "modules.json"), "w", encoding="utf-8") as f:
    json.dump(inventory, f, indent=2, ensure_ascii=False)

coverage = {
    "coverage": {
        "modules": len(module_list),
        "documented": sum(1 for m in module_list if m["haddock_comments"] > 0),
        "percentage": round(
            sum(1 for m in module_list if m["haddock_comments"] > 0) / max(len(module_list), 1) * 100, 1
        ),
    }
}
with open(os.path.join(OUT_DIR, "coverage.json"), "w", encoding="utf-8") as f:
    json.dump(coverage, f, indent=2, ensure_ascii=False)

functions_inv = {"functions": function_list, "total_functions": len(function_list)}
with open(os.path.join(OUT_DIR, "functions.json"), "w", encoding="utf-8") as f:
    json.dump(functions_inv, f, indent=2, ensure_ascii=False)

print(f"Generated inventory: {len(module_list)} modules, {len(function_list)} functions in {OUT_DIR}")
