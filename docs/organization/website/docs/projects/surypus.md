# Projects

## Surypus ERP/CRM

**Система управления предприятием нового поколения на Haskell с формальной верификацией**

### Verification & Test Stats

| Metric | Value |
|---|---|
| License | MPL-2.0 |
| Haskell modules | 486 |
| Test suites (Haskell) | 69 files in `test/` |
| Property-based tests | 3 |
| Integration suites | 8 |
| SQL test scripts | 116 in `sql/test/` |
| RBAC permissions | 33 |
| Formal verification | LiquidHaskell (optional) |
| Toolchain | GHC 9.6.5 · Persistent 2.18 · Esqueleto 3.6 · PostgreSQL · Scotty |

### Quick Start

```bash
# Build project
stack build Surypus

# Run tests
stack test

# Format code
fourmolu -i src/ test/

# Lint code
hlint src/ test/
```

### Architecture

- **Core/** - Domain logic (Tax, Accounting, Warehouse)
- **DAL/** - Database access (Queries, Mutations, Types)
- **Surypus/** - Utilities (Types, Z3, I18n)
- **API/** - REST API (Scotty)

## Roadmap

### v2.0 GUI & Features (Complete)
- [x] Infrastructure cycles Phases 160–171
- [x] GUI & Features Phases 13–21

### v3.0 Infrastructure (In Progress)
- [ ] Docker multi-arch builds
- [ ] Nix flake for reproducible builds
- [ ] Cross-compilation binaries
- [ ] Performance benchmarking

### v4.0 Formal Verification (Planned)
- [ ] LiquidHaskell coverage expansion
- [ ] Property-based testing with QuickCheck
- [ ] Chaos engineering
- [ ] GHC performance tracking
