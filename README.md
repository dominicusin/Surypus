# Surypus ERP/CRM

**Haskell ERP prototype with formal verification in selected areas**

[![License: MPL-2.0](https://img.shields.io/badge/License-MPL%202.0-blue.svg)](https://opensource.org/licenses/MPL-2.0)
[![Haskell](https://img.shields.io/badge/Language-Haskell-5e5086?logo=haskell)](https://www.haskell.org/)
[![GHC](https://img.shields.io/badge/GHC-9.6.6-5e5086)](https://www.haskell.org/ghc/)
[![Stack](https://img.shields.io/badge/Stack-2.13+-5e5086)](https://docs.haskellstack.org/)
[![CI](https://github.com/surypus/surypus/workflows/CI/badge.svg)](https://github.com/surypus/surypus/actions/workflows/ci.yml)

---

## Overview

Surypus is an experimental Haskell ERP/CRM prototype. It focuses on a narrow verifiable core: tax calculations, double-entry accounting, JWT auth with refresh rotation, RBAC, and bill posting.

This repository is not production-ready. The current goal is one green vertical slice, not broad feature coverage.

## Current status

- Prototype stage
- One working scenario: bill posting with audit trail
- Verified core: `Finance.Tax`, `Finance.Accounting`, `DAL.Types`
- Stack resolver: `lts-22.21`
- GHC: `9.6.6`

## Getting started

```bash
stack build
stack test
stack run
```

## Documentation

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [SECURITY.md](SECURITY.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- [GOVERNANCE.md](GOVERNANCE.md)

## License

MPL-2.0
