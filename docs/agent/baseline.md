# Surypus Baseline Documentation

> Generated: 2026-09-02
> Purpose: Document reproducible baseline for build/test/codegen/LiquidHaskell/SQL/docs

## Toolchain Versions

| Tool | Version | Notes |
|------|---------|-------|
| GHC | 9.2.8 | Glasgow Haskell Compiler |
| Cabal | 3.6.2.0 | cabal-install version |
| Stack | NOT FOUND | Not installed |
| PostgreSQL client | 18.4 | psql |
| LiquidHaskell | NOT FOUND | Not installed |
| Python3 | 3.12.13 | System Python |

## Build Baseline

```bash
# Primary build command
cabal build --enable-tests --disable-optimization

# Test command
cabal test --test-options="--color=always"

# Haddock generation
cabal haddock --haddock-options="--hyperlink-source --quickjump"

# Hoogle generation
hoogle generate --local
```

## Test Baseline

```bash
# Unit tests
cabal test

# Property tests (QuickCheck)
cabal test --test-options="--quickcheck-tests=1000"
```

## Documentation Baseline

```bash
# MkDocs build
/home/domini/.local/bin/mkdocs build --strict

# Documentation validation
./tools/documentation/check-docs.sh
```

## Known Limitations

1. Stack is not installed
2. LiquidHaskell is not installed
3. SQL test runner not yet configured
