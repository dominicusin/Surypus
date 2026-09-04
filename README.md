# Surypus ERP/CRM

**Система управления предприятием нового поколения на Haskell с формальной верификацией**

[![License: MPL-2.0](https://img.shields.io/badge/License-MPL%202.0-blue.svg)](https://opensource.org/licenses/MPL-2.0)
[![Haskell](https://img.shields.io/badge/Language-Haskell-5e5086?logo=haskell)](https://www.haskell.org/)
[![GHC](https://img.shields.io/badge/GHC-9.6.6+-5e5086)](https://www.haskell.org/ghc/)
[![Stack](https://img.shields.io/badge/Stack-2.13+-5e5086)](https://docs.haskellstack.org/)
[![CI](https://github.com/surypus/surypus/workflows/CI/badge.svg)](https://github.com/surypus/surypus/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/surypus/surypus/branch/main/graph/badge.svg)](https://codecov.io/gh/surypus/surypus)
[![Release](https://img.shields.io/github/v/release/surypus/surypus)](https://github.com/surypus/surypus/releases)
[![Issues](https://img.shields.io/github/issues/surypus/surypus)](https://github.com/surypus/surypus/issues)
[![Pull Requests](https://img.shields.io/github/issues-pr/surypus/surypus)](https://github.com/surypus/surypus/pulls)
[![Contributors](https://img.shields.io/github/contributors/surypus/surypus)](https://github.com/surypus/surypus/graphs/contributors)
[![Stars](https://img.shields.io/github/stars/surypus/surypus)](https://github.com/surypus/surypus/stargazers)
[![Wiki](https://img.shields.io/badge/Wiki-Documentation-blue)](https://github.com/surypus/surypus/wiki)

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [License](#license)
- [Support](#support)

---

## Why Surypus?

Traditional ERP systems are complex, error-prone, and expensive. Surypus offers a different approach:

- **Correctness by construction** - Formal verification eliminates entire classes of bugs
- **Type safety** - Haskell's type system prevents runtime errors
- **Transparency** - Open source means no vendor lock-in
- **Community-driven** - Built by the community, for the community

---

## Overview

Surypus is a production-ready ERP/CRM system written in Haskell with emphasis on formal verification, type safety, and software correctness. It demonstrates the power of functional programming and formal methods in real-world business software.

### Why Haskell?

- **Type safety** - Catch bugs at compile time
- **Purity** - Predictable, testable code
- **Formal verification** - Prove correctness with LiquidHaskell
- **Concurrency** - Safe, composable parallelism
- **Performance** - Compiled to native code

### Why Surypus?

- **Formally verified** - LiquidHaskell refinements prove invariants
- **Type-safe database** - Persistent + Esqueleto prevent SQL injection at type level
- **Event sourcing** - Complete audit trail
- **RBAC** - 33 granular permissions
- **Production-ready** - 61+ CI/CD workflows, comprehensive testing

---

## Features

### Core ERP/CRM

- ✅ **Accounting** - General ledger, double-entry bookkeeping, trial balance
- ✅ **Inventory** - Goods management, stock levels, warehouse operations
- ✅ **Tax** - VAT calculations with formal verification
- ✅ **RBAC** - 33 permissions, dynamic roles, audit logging
- ✅ **API** - REST API with OpenAPI documentation
- ✅ **Event Sourcing** - Complete audit trail, event replay
- ✅ **Reports** - Balance sheet, income statement, inventory reports

### Technical Features

- ✅ **Formal Verification** - LiquidHaskell refinement types
- ✅ **Type-Safe Database** - Persistent + Esqueleto
- ✅ **REST API** - Scotty web framework
- ✅ **JSON API** - Aeson serialization
- ✅ **WebSocket** - Real-time notifications
- ✅ **Authentication** - JWT tokens, bcrypt password hashing
- ✅ **Docker** - Multi-arch container builds
- ✅ **Nix** - Reproducible builds

### Quality Metrics

| Metric | Value |
|--------|-------|
| Haskell modules | 486 |
| Test suites | 69 files |
| Property-based tests | 3 |
| Integration suites | 8 |
| SQL test scripts | 116 |
| RBAC permissions | 33 |
| Code coverage | 80%+ |

---

## Quick Start

### Prerequisites

- **GHC** 9.6.6 or later
- **Stack** 2.13 or later
- **PostgreSQL** 14 or later

### Installation

```bash
# Clone the repository
git clone https://github.com/surypus/surypus.git
cd Surypus

# Build the project
stack build

# Run tests
stack test

# Run the API server
stack run
```

### Docker

```bash
# Build Docker image
docker build -t surypus .

# Run with Docker Compose
docker compose up
```

### devcontainer

For a consistent development environment:

1. Open in VS Code with Remote Containers extension
2. Click "Reopen in Container"
3. All tools and dependencies will be automatically installed

---

## Documentation

### Getting Started

- [README](README.md) - This file
- [CONTRIBUTING](CONTRIBUTING.md) - How to contribute
- [CHANGELOG](CHANGELOG.md) - Version history
- [CODE_OF_CONDUCT](CODE_OF_CONDUCT.md) - Community standards
- [ENFORCEMENT](ENFORCEMENT.md) - Code of Conduct enforcement
- [SECURITY](SECURITY.md) - Security policy
- [GOVERNANCE](GOVERNANCE.md) - Project governance

### Architecture

- [Architecture Overview](docs/architecture/ARCHITECTURE.md)
- [RBAC Canonicalization](sql/docs/RBAC_CANON.md)
- [Audit/Logs](sql/docs/AUDIT.md)
- [API Documentation](API_DOCUMENTATION.md)
- [Multi-Repo Architecture](docs/organization/multi-repo-architecture.md)

### Development

- [Code Review Guidelines](CODE_REVIEW_GUIDELINES.md)
- [ADR Templates](docs/adr/0000-template.md)
- [Issue Templates](.github/ISSUE_TEMPLATE/)

### External Resources

- [Haskell Documentation](https://www.haskell.org/documentation/)
- [Stack Documentation](https://docs.haskellstack.org/)
- [Persistent Documentation](https://www.yesodweb.com/book/persistent)
- [LiquidHaskell](https://liquidhaskell.github.io/)

---

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Quick Start for Contributors

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Run tests: `stack test`
5. Format code: `fourmolu -i src/ test/`
6. Commit and push
7. Create a Pull Request

### Code of Conduct

This project adheres to a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

---

## Roadmap

### v2.0 Production Ready ✅
- [x] Core infrastructure (Phases 160-171)
- [x] GUI & Features (Phases 13-21)
- [x] CI/CD pipeline with 61+ workflows
- [x] Docker support
- [x] Nix flake
- [x] devcontainer
- [x] Security hardening
- [x] Documentation

### v2.1 Performance & Observability
- [ ] OpenTelemetry tracing
- [ ] Prometheus metrics
- [ ] Structured logging
- [ ] Distributed tracing
- [ ] Performance benchmarking

### v3.0 Multi-Repo Architecture
- [ ] Extract surypus-core
- [ ] Extract surypus-dal
- [ ] Extract surypus-api
- [ ] API gateway
- [ ] Event bus

### v4.0 Formal Verification
- [ ] LiquidHaskell coverage expansion
- [ ] Property-based testing
- [ ] Chaos engineering
- [ ] GHC performance tracking

---

## Community

Surypus is more than just code - it's a community of developers, users, and contributors who believe in the power of formal verification and type safety.

### Getting Involved

- 📖 Read our [Community Guide](COMMUNITY.md)
- 💬 Join [GitHub Discussions](https://github.com/surypus/surypus/discussions)
- 🐛 Report bugs via [GitHub Issues](https://github.com/surypus/surypus/issues)
- 🤝 Contribute using our [Contributing Guidelines](CONTRIBUTING.md)

### Code of Conduct

This project adheres to a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

---

## License

Surypus is licensed under the [Mozilla Public License 2.0](LICENSE).

### Why MPL-2.0?

- **File-level copyleft** - Changes to Surypus files must be shared
- **Compatible with proprietary code** - Can be used in proprietary projects
- **Patent protection** - Explicit patent grant from contributors
- **Simpler than GPL** - Less restrictive for commercial use

---

## Support

### Getting Help

- [GitHub Issues](https://github.com/surypus/surypus/issues) - Bug reports and feature requests
- [GitHub Discussions](https://github.com/surypus/surypus/discussions) - Questions and ideas
- [GitHub Wiki](https://github.com/surypus/surypus/wiki) - Documentation and guides

### Reporting Security Issues

Please see our [Security Policy](SECURITY.md) for reporting vulnerabilities.

### Commercial Support

For commercial support, consulting, or custom development, please contact the maintainers.

---

## Maintainer Resources

We're committed to supporting the wellbeing of our maintainers. If you're a maintainer or planning to become one, these resources are for you:

| Resource | Description |
|----------|-------------|
| [Maintainer Wellbeing & Sustainability](MAINTAINER_WELLBEING.md) | Complete guide to sustainable maintainership |
| [Self Care Guide](docs/maintainer/self-care-guide.md) | Burnout signs, motivation, energy management |
| [Sustainability Guide](docs/maintainer/sustainability.md) | Time/energy expectations, delegation, funding, automation |
| [Rest Policy](docs/maintainer/rest-policy.md) | Planned and unplanned breaks, coverage plans |
| [Boundaries Guide](docs/maintainer/boundaries.md) | Time, scope, communication, emotional boundaries with templates |
| [Blocking Issues](docs/maintainer/blocking-issues.md) | What to do when you're stuck, escalation paths |

### Burnout Check

Every Monday, a bot posts a [weekly check-in issue](../../issues?q=is%3Aissue+label%3Amaintainer-checkin) to help maintainers reflect on their wellbeing. Feel free to respond or ignore as you prefer.

**Your wellbeing comes first. Take breaks when you need them. Set boundaries without guilt.**

## Sponsors

Surypus is supported by our amazing sponsors. Thank you! ❤️

### Corporate Sponsors

- (No corporate sponsors yet - be the first!)

### Individual Supporters

- (No individual supporters yet - be the first!)

### Become a Sponsor

If you find Surypus useful, please consider supporting us:

- [GitHub Sponsors](https://github.com/sponsors/dominicusin)
- [Open Collective](https://opencollective.com/surypus)
- [Corporate Sponsorship](SPONSORSHIP.md)

See [FUNDING.md](FUNDING.md) for all ways to support Surypus.

---

## Acknowledgments

- [Haskell Community](https://www.haskell.org/) - For the amazing language and ecosystem
- [LiquidHaskell](https://liquidhaskell.github.io/) - For formal verification tools
- [Yesod/Persistent](https://www.yesodweb.com/) - For type-safe database access
- All [contributors](https://github.com/surypus/surypus/graphs/contributors) who have helped improve this project

---

<div align="center">

⭐ **Star us on GitHub** if you find this project useful! ⭐

Made with ❤️ by the Surypus Team

</div>
