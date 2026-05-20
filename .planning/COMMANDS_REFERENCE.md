# Surypus Project Commands Reference

Quick reference for common development tasks.

## Build & Compilation

### Full Build
```bash
stack build
```

### Build with Verbose Output
```bash
stack build --verbose
```

### Build Specific Package
```bash
stack build Surypus           # Main library
stack build surypus-api       # API server
stack build Surypus:surypus-api-exe  # API executable
```

### Clean Build
```bash
stack clean
stack build
```

### View Build Errors
```bash
stack build 2>&1 | grep -E "(error|Error)"
```

### View Build Warnings
```bash
stack build 2>&1 | grep -E "(warning|Warning)"
```

---

## Testing

### Run All Tests
```bash
stack test
```

### Run Specific Test Suite
```bash
stack test Surypus:surypus-test
stack test surypus-api:surypus-api-test
```

### Run Tests with Verbose Output
```bash
stack test --verbose
```

### Run Tests with Coverage
```bash
stack test --coverage
```

### Run Specific Test (by name)
```bash
stack test --test-arguments="-m <test-name>"
```

---

## Running the Application

### Run API Server
```bash
stack exec surypus-api
```

### Run API Server with Custom Port
```bash
stack exec surypus-api -- --port 9000
```

### Run API Server in Background
```bash
stack exec surypus-api &
```

---

## Development Workflow

### Load Module in GHCi (Interactive Repl)
```bash
stack ghci
# Inside ghci:
:load src/HR/Person.hs
:reload
:type functionName
:info TypeName
```

### Check Module Compilation
```bash
stack build --ghc-options="-fno-code"
```

### Format Code (if fourmolu/ormolu available)
```bash
stack install fourmolu
fourmolu -i src/**/*.hs
```

### Lint Code (if hlint available)
```bash
stack install hlint
hlint src/
```

---

## Investigation & Debugging

### List Available Modules
```bash
stack build --dry-run 2>&1 | grep "Compiling"
```

### Check Dependencies
```bash
stack list-bin Surypus
stack path
```

### View Installed Packages
```bash
stack exec ghc-pkg -- list
```

### Check GHC Version
```bash
stack ghc -- --version
```

### View Build Directory Structure
```bash
ls -la .stack-work/dist/x86_64-linux-tinfo6/ghc-9.6.5/build/
```

---

## Documentation

### Generate Haddock Documentation
```bash
stack haddock
```

### View Haddock in Browser (after generation)
```bash
open .stack-work/install/x86_64-linux-tinfo6/*/ghc-*/share/doc/*/html/index.html
```

### Check Module Documentation
```bash
stack exec ghc -- -haddock src/DAL/DB.hs
```

---

## Dependency Management

### View Dependencies
```bash
cat stack.yaml       # Project configuration
cat Surypus.cabal    # Package dependencies
```

### Update Dependencies
```bash
stack setup          # Install GHC if needed
stack update         # Update package index
stack build --dependencies-only
```

### Add New Dependency
1. Edit `Surypus.cabal` (add to `build-depends`)
2. Run `stack setup` to fetch new packages
3. Run `stack build` to rebuild

---

## Troubleshooting

### Clear Stack Cache
```bash
rm -rf .stack-work/
stack setup
stack build
```

### Check for Circular Dependencies
```bash
stack ghc -- -fno-code -O0 src/**/*.hs 2>&1 | grep -i "circular"
```

### Force Rebuild of All Modules
```bash
stack clean
stack build --force-dirty
```

### View Available Executables
```bash
stack exec which surypus-api
stack list-bin surypus-api
```

### Test Build Without Warnings (in chunks)
```bash
stack build 2>&1 | tee build.log
grep -c "warning" build.log
```

---

## Project Planning & Documentation

### View Current Plan
```bash
cat .planning/BUILD_PLAN.md
cat .planning/STATUS_REPORT.md
```

### Update Plan Status
```bash
# Edit .planning/BUILD_PLAN.md
# Mark completed chunks with ✅
# Update timeline estimates
git add .planning/BUILD_PLAN.md
git commit -m "Update plan status"
```

---

## Git Workflow

### View Status
```bash
git status
```

### Stage Changes
```bash
git add src/
git add .planning/
```

### Commit Changes
```bash
git commit -m "Chunk 1: Stabilize DAL types and add tests"
```

### View Changes
```bash
git diff src/DAL/DB.hs
git log --oneline -10
```

### Create Feature Branch
```bash
git checkout -b chunk-1/dal-stabilization
```

### Push Branch
```bash
git push origin chunk-1/dal-stabilization
```

---

## Performance & Analysis

### Check Build Performance
```bash
time stack build
```

### Profile Compilation
```bash
stack build --profile
```

### Analyze Module Dependencies
```bash
stack ghc -- -e "import Data.Graph" -e "..." src/DAL/DB.hs
```

---

## Quick Commands Cheat Sheet

| Task | Command |
|------|---------|
| Build | `stack build` |
| Test | `stack test` |
| Run API | `stack exec surypus-api` |
| Interactive | `stack ghci` |
| Clean | `stack clean` |
| Format | `fourmolu -i src/**/*.hs` |
| Lint | `hlint src/` |
| Docs | `stack haddock` |
| Check errors | `stack build 2>&1 \| grep error` |
| Check warnings | `stack build 2>&1 \| grep warning` |

---

## Useful Tips

1. **Use `stack ghci` for iterative development**
   - Load modules and test functions interactively
   - Faster feedback loop than full rebuild

2. **Run tests after every change**
   - `stack test` ensures no regressions
   - Catch issues early

3. **Build frequently**
   - Catch compilation errors immediately
   - Stack caches incremental builds

4. **Check warnings regularly**
   - Unused imports can hide real issues
   - Fix warnings before they become problems

5. **Use proper branch names**
   - Helps track which chunk is being worked on
   - Easier code review and cherry-picking

---

**Last Updated**: 2024
