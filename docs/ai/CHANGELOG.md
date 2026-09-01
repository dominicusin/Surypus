# CHANGELOG

## Documentation Pipeline Changelog

This file tracks changes to the documentation infrastructure itself.

## 2026-08-31 — Documentation Factory v1.0

### Added
- `.github/workflows/documentation.yml` — validation workflow (Haddock, doctest, Hoogle, inventory, module graph, drift detection)
- `.github/workflows/documentation-deploy.yml` — deployment workflow to GitHub Pages
- `.github/workflows/ci.yml` — docs job (MkDocs build, Haddock, Hoogle, inventory, module graph, drift detection)
- `tools/documentation/generate-module-graph.sh` — generate Mermaid module dependency graph from `src/`
- `tools/documentation/generate-module-graph.hs` — Haskell reference implementation of module graph generator
- `tools/documentation/generate-inventory.py` — generate `docs/generated/inventory/{modules,functions,coverage}.json`
- `tools/documentation/generate-hoogle.sh` — copy Hoogle database to `docs/generated/hoogle/`
- `tools/documentation/check-docs.sh` — 5-point validation (MkDocs strict, module graph, inventory JSON, coverage, no manual edits to `docs/generated/`)
- `docs/generated/graphs/modules.mmd` — module dependency diagram (1,638 lines)
- `docs/generated/graphs/architecture.mmd` — high-level architecture diagram
- `docs/generated/hoogle/hoogle.hoo` + `hoogle.txt` — Hoogle search index
- `docs/generated/inventory/modules.json` — 412 modules, 3,811 functions
- `docs/generated/inventory/coverage.json` — 86.7% module-level haddock coverage
- `docs/ai/DOCUMENTATION_RULES.md` — AI documentation agent contract
- `docs/ai/COVERAGE.md` — documentation coverage report
- `AGENTS.md` — documentation protocol appended

### Principles
- **AI не является источником истины.** GHC, Cabal, Haddock, исходный код и исполняемые тесты — источники истины.
- `docs/generated/` — не редактируется человеком.
- Every public API change requires documentation review.

## 2026-09-01 — Secrets Policy + CI Guard

### Added
- AGENTS.md Secrets Policy section
- .github/workflows/secret-guard.yml: CI scan for high-entropy secrets
- .gitignore guards for ReadTheDocs API keys and secret files

### Security
- Removed accidental documentation of exposed ReadTheDocs API key
- Added rotation reminder in CHANGELOG
