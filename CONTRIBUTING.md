# Contributing to Surypus

Thank you for your interest in contributing to Surypus! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Enhancements](#suggesting-enhancements)
- [Development Workflow](#development-workflow)
- [Code Standards](#code-standards)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)
- [Review Process](#review-process)
- [Community](#community)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to the maintainers.

## Getting Started

### Prerequisites

- **GHC** 9.6.6 or later
- **Stack** 2.13 or later
- **PostgreSQL** 14 or later
- **Git** 2.30 or later
- **Docker** (optional, for containerized development)

### Setting Up Development Environment

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/Surypus.git
   cd Surypus
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/surypus/surypus.git
   ```
4. **Install dependencies**:
   ```bash
   stack build
   ```
5. **Run tests** to verify setup:
   ```bash
   stack test
   ```

### Using devcontainer (Recommended)

For a consistent development environment, use the included devcontainer configuration:

1. Open in VS Code with Remote Containers extension
2. Click "Reopen in Container"
3. All tools and dependencies will be automatically installed

## How to Contribute

### Reporting Bugs

Before creating a bug report, please check the [existing issues](../../issues) to avoid duplicates.

When creating a bug report, include:

- **Clear title** and description
- **Steps to reproduce** the behavior
- **Expected behavior** vs actual behavior
- **Environment details** (OS, GHC version, Stack version)
- **Code samples** or test cases if applicable
- **Screenshots** if relevant

Use the [Bug Report template](../../issues/new?template=bug_report.yml) for structured reports.

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear, descriptive title**
- **Provide detailed description** of the proposed feature
- **Explain why this enhancement would be useful**
- **Include examples** of how it would be used
- **Consider implementation** details if possible

Use the [Feature Request template](../../issues/new?template=feature_request.yml) for structured suggestions.

## Development Workflow

### Branching Strategy

We use a simplified Git Flow workflow:

- `main` - stable production-ready code
- `feature/*` - new features
- `bugfix/*` - bug fixes
- `hotfix/*` - urgent production fixes
- `release/*` - release preparation

### Workflow Steps

1. **Create a branch** from `main`:
   ```bash
   git checkout main
   git pull upstream main
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following our code standards

3. **Write tests** for new functionality

4. **Run tests** locally:
   ```bash
   stack test
   ```

5. **Format code**:
   ```bash
   fourmolu -i src/ test/
   ```

6. **Lint code**:
   ```bash
   hlint src/ test/
   ```

7. **Commit changes** following our commit message conventions

8. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

9. **Create a Pull Request** against `main`

## Code Standards

### Haskell Style

- Follow **Haskell2010** standard
- Use **2-space indentation** (no tabs)
- Maximum **100 characters** per line
- Use **explicit imports** (no wildcard imports)
- Add **Haddock comments** to all public functions
- Keep **functions small and focused**
- Use **meaningful names** for types, functions, and variables

### Module Organization

```haskell
-- Module header with description
-- | Brief description of the module purpose.
module Module.Name (exported, functions) where

-- Imports in order: external, qualified, local
import qualified Data.Text as T
import Data.Text (Text)

import Core.Tax
import DAL.Types

-- Type definitions
-- Function implementations
-- Property tests (if applicable)
```

### Testing Standards

- **Unit tests** for all public functions
- **Property-based tests** for invariants (QuickCheck)
- **Integration tests** for database operations
- **Minimum 80% code coverage**
- Tests should be **independent** and **deterministic**

### Documentation

- **Haddock comments** for all public APIs
- **README updates** for new features
- **CHANGELOG entry** for all changes
- **ADR (Architecture Decision Record)** for significant decisions

## Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<optional scope>): <description>

[optional body]

[optional footer(s)]
```

### Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, semicolons, etc.)
- **refactor**: Code refactoring without behavior change
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **build**: Build system or dependency changes
- **ci**: CI/CD configuration changes
- **chore**: Other changes that don't modify src or test
- **revert**: Reverting previous changes

### Examples

```
feat(tax): add VAT calculation for reverse charge

Implement VAT calculation for reverse charge mechanism
used in B2B EU transactions.

Closes #123
```

```
fix(inventory): correct stock level calculation

Fixed off-by-one error in stock level calculation
when processing multiple concurrent transactions.

Fixes #456
```

## Pull Request Process

1. **Update documentation** if your change affects public APIs
2. **Add tests** for new functionality
3. **Ensure all tests pass** locally
4. **Update CHANGELOG.md** with your change
5. **Fill out the PR template** completely
6. **Request review** from at least one maintainer
7. **Address review feedback** promptly and respectfully

### PR Title Format

Follow the same convention as commit messages:

```
feat(scope): description
fix(scope): description
```

### PR Description

Your PR description should include:

- **What** changes were made
- **Why** the changes were necessary
- **How** the changes were implemented
- **Testing** that was performed
- **Screenshots** if applicable
- **Related issues** (use `Closes #123` or `Relates to #456`)

## Review Process

### For Contributors

- Respond to review comments **within 7 days**
- Ask questions if feedback is unclear
- Be open to suggestions and alternatives
- Make requested changes in **new commits** (don't force push)

### For Reviewers

- Review PRs **within 48 hours**
- Provide **constructive, specific feedback**
- Approve with comments when minor changes are requested
- Use **conventional comments**:
  - **nit**: Minor suggestion, not blocking
  - **question**: Needs clarification
  - **issue**: Must be addressed
  - **praise**: Highlight good practices

## Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and ideas
- **GitHub Wiki**: Documentation and guides

### Recognition

Contributors will be recognized in:

- **Release notes** for significant contributions
- **CONTRIBUTORS.md** file (coming soon)
- **GitHub contributors** page

## Questions?

If you have questions not covered here:

1. Check the [documentation](docs/)
2. Search [existing issues](../../issues)
3. Open a [new discussion](../../discussions)

Thank you for contributing to Surypus! 🚀
