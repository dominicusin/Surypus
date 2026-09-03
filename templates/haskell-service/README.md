# Haskell Service

Production-ready Haskell service template with Stack, CI/CD, and GitHub best practices.

## Features

- Stack-based build with GHC 9.6.6+
- GitHub Actions CI/CD (test, lint, format, coverage)
- Dependabot for dependency updates
- Pre-commit hooks (fourmolu, hlint)
- Nix flake for reproducible builds
- devcontainer for GitHub Codespaces
- Docker support with multi-arch builds
- Security hardening (secret scanning, SBOM)
- ADR templates for architecture decisions
- Standardized labels and issue templates

## Quick Start

```bash
# Clone and enter directory
cd <project-name>

# Build with Stack
stack build

# Run tests
stack test

# Format code
fourmolu -i src/ test/

# Lint code
hlint src/ test/

# Build with Nix
nix develop
stack build

# Run with Docker
docker compose up
```

## Project Structure

```
.
├── .github/
│   ├── workflows/       # CI/CD workflows
│   ├── ISSUE_TEMPLATE/  # Issue forms
│   ├── dependabot.yml   # Dependency updates
│   ├── labels.yml       # Repository labels
│   └── CODEOWNERS       # Code owners
├── .devcontainer/       # GitHub Codespaces config
├── app/                 # Application entry point
├── src/                 # Library source
├── test/                # Test suite
├── docs/
│   └── adr/            # Architecture Decision Records
├── packaging/           # Docker packaging
├── .gitignore
├── CHANGELOG.md
├── LICENSE
├── README.md
├── cabal.project
├── flake.nix
├── package.yaml
└── stack.yaml
```

## Customization

1. Update `package.yaml` with your package details
2. Add dependencies to `stack.yaml` if needed
3. Customize `.github/workflows/ci.yml` for your needs
4. Update `.github/CODEOWNERS` with your team
5. Add project-specific ADRs to `docs/adr/`

## License

MPL-2.0
