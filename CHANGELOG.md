# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Reusable GitHub Actions: `haskell-setup`, `haskell-test`, `haskell-lint`
- Property-based testing with QuickCheck workflow
- LiquidHaskell formal verification workflow
- Stackage Nightly auto-PR workflow
- Security advisory automation
- Multi-repository architecture documentation
- Chaos engineering workflow
- GHC performance tracking with matrix (9.6.6, 9.8.2, 9.10.1)
- Mobile cross-compilation (iOS, Android, WASM)
- OIDC cloud deployment workflow
- Copilot code review automation
- Hackage publishing pipeline
- GraphQL API workflow
- Background jobs workflow
- Observability workflow
- Database schema versioning workflow
- Feature flags workflow
- API rate limiting workflow
- Circuit breaker workflow
- Health checks workflow
- Graceful shutdown workflow
- CONTRIBUTING.md with comprehensive guidelines
- CODE_REVIEW_GUIDELINES.md for reviewers
- GOVERNANCE.md for project governance
- CHANGELOG.md for tracking changes

### Changed
- Improved CODE_OF_CONDUCT.md with detailed enforcement
- Enhanced PULL_REQUEST_TEMPLATE.md with comprehensive sections
- Updated SECURITY.md with supported versions and disclosure policy
- Enhanced README.md with badges and clear structure

### Security
- Enabled secret scanning and push protection
- Enabled Dependabot alerts and security updates
- Added security hardening workflow
- Added supply chain security workflow
- Added SBOM and attestation workflow

## [0.1.0] - 2026-09-03

### Added
- Initial Haskell ERP/CRM implementation with formal verification
- Core domain modules: Tax, Accounting, Inventory
- Database access layer with Persistent and Esqueleto
- REST API server with Scotty
- LiquidHaskell refinement types for critical invariants
- Comprehensive CI/CD pipeline with GitHub Actions
- Docker support with multi-arch builds
- Nix flake for reproducible builds
- devcontainer for GitHub Codespaces
- 61+ GitHub Actions workflows for complete automation
- 4 issue templates (bug, feature, security, config)
- 30 labels for issue and PR classification
- 4 milestones for roadmap tracking
- Repository rulesets for branch protection
- Advanced security features (secret scanning, code scanning)
- Organization documentation and governance
- GitHub Pages with MkDocs Material website

[Unreleased]: https://github.com/surypus/surypus/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/surypus/surypus/releases/tag/v0.1.0
