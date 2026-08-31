# Surypus Documentation Agent Rules

## Source of Truth

The following are authoritative:

1. **GHC** — actual Haskell types and modules
2. **Cabal** — components, dependencies, exposed-modules
3. **Haddock** — API reference (generated)
4. **doctest** — executable examples (verified)
5. **Hoogle** — type-level search (generated)
6. **Haskell source code** — ground truth for behaviour
7. **Git** — history and changes
8. **tests/** — executable specifications

**AI-generated prose is never authoritative.**

## Never

- Invent APIs, module names, or dependencies
- Invent behaviour, database schemas, or invariants
- Modify `docs/generated/` manually
- Claim an example works unless doctest verifies it
- Change a public API without updating Haddock
- Write prose that contradicts Haddock types

## Always

- Inspect the actual source before describing it
- Inspect Haddock output before documenting APIs
- Inspect git diff before writing change notes
- Preserve existing architectural decisions
- Distinguish facts from interpretation
- Link claims to source modules (e.g., `Core.Tax.calcVAT`)
- Add executable doctest examples when possible
- Update Mermaid diagrams when modules are added/removed

## Documentation Levels

| Level | Scope | Example |
|-------|-------|---------|
| L0 | Internal helper | `uncons'` in a module |
| L1 | Module header + exports | `module Core.Tax (...) where` |
| L2 | Function/type/class docs | `-- | Calculate VAT` |
| L3 | Executable doctest | `-- >>> calcVAT 100 0.2` |
| L4 | Architecture + module graph | Mermaid diagrams |
| L5 | Domain + user guides | `docs/guides/tax.md` |

## Pull Request Rule

If a public API changes:

1. Update Haddock documentation
2. Add or update doctest examples
3. Check `mkdocs build --strict`
4. Regenerate module graph: `./tools/documentation/generate-module-graph.sh`
5. Check architecture impact
6. Update relevant domain guide
7. Never commit to `docs/generated/` without regeneration

## AI Agent Loop

```
Beads change → diff → Haddock + doctest + Hoogle + module graph
                    │
                    ▼
           Documentation Inventory
                    │
                    ▼
           Documentation Reviewer
                    │
            ┌───────┴───────┐
            ▼               ▼
          PASS            FAIL
            │               │
            ▼               ▼
        deploy docs    PR comment + task
```

## Validation Gate

Every documentation change must pass:

1. `mkdocs build --strict` — no warnings
2. `doctest src/` — all examples pass
3. `haddock --help` — all exported symbols documented
4. Module graph regenerates without errors
5. `docs/generated/inventory/modules.json` is consistent
