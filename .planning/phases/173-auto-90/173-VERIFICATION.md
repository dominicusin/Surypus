---
phase: 173
status: tech_debt
verified: 2026-05-28
---

# Phase 173 Verification: Toolchain Installation

## Results

| Tool | Status |
|------|--------|
| ghcid | ✅ installed (`/home/domini/.local/bin/ghcid`) |
| cabal-fmt | ✅ installed (`/home/domini/.local/bin/cabal-fmt`) |
| weeder | ✅ installed (`/home/domini/.local/bin/weeder`) |
| hoogle | ✅ pre-installed |
| hlint | ✅ pre-installed (`/home/domini/.nix-profile/bin/hlint`) |
| doctest | ✅ pre-installed (`/usr/bin/doctest`) |
| fourmolu | ✅ installed (`/home/domini/.nix-profile/bin/fourmolu`) |
| stan | ⚠️ deferred — not on PATH |
| cabal-audit | ⚠️ deferred — not on PATH |

## Human Verification Resolution

The previously requested human check was completed on 2026-05-28. `fourmolu` is now available on PATH. `stan` and `cabal-audit` remain non-blocking toolchain debt because the shipped v55 project state only depends on the core formatter/lint/build toolchain, while these two tools had dependency/build issues under the current environment.
