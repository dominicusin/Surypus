# ADR-005: MkDocs for Documentation Site

**Status:** Accepted
**Date:** 2026-08-31

## Decision

Use MkDocs with Material theme for the documentation website.

## Rationale

- Markdown-based documentation (consistent with project style)
- Material for MkDocs provides excellent theme and search
- ReadTheDocs native support for MkDocs
- Easy to extend with plugins (mkdocstrings, pymdown-extensions)

## Consequences

- `mkdocs.yml` at repository root
- `docs/mkdocs.yml` for ReadTheDocs
- Site built with `mkdocs build --strict`
- Published to GitHub Pages and ReadTheDocs
- Formats: HTML, PDF, EPUB, HTMLZip

---

## ADR-006: Documentation AI-agent Contract

**Status:** Accepted
**Date:** 2026-08-31

## Decision

Define a strict contract for AI documentation agents in `docs/ai/DOCUMENTATION_RULES.md`.

## Rationale

- AI must not be the source of truth for API semantics
- AI-generated prose must be verified against Haddock and doctest
- Every public API change requires documentation review

## Consequences

- `docs/ai/DOCUMENTATION_RULES.md` defines source of truth, never/always rules, documentation levels L0-L5, PR rules
- `AGENTS.md` includes Documentation Protocol section
- `docs/ai/COVERAGE.md` tracks documentation coverage metrics
- `docs/ai/CHANGELOG.md` tracks documentation infrastructure changes

## Principles

> **AI не является источником истины.**
> AI interprets facts from GHC/Cabal/Haddock/tests; AI is NOT the source of truth.
