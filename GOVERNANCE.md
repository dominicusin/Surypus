# Surypus Governance

This document describes the governance structure for the Surypus project.

## Table of Contents

- [Project Overview](#project-overview)
- [Roles and Responsibilities](#roles-and-responsibilities)
- [Decision Making](#decision-making)
- [Contribution Process](#contribution-process)
- [Release Process](#release-process)
- [Code of Conduct](#code-of-conduct)
- [License](#license)

## Project Overview

Surypus is an open source ERP/CRM system implemented in Haskell with formal verification. The project emphasizes type safety, correctness, and software quality.

### Mission

To build a production-ready, type-safe accounting and event-sourcing system that demonstrates the power of formal methods in real-world software.

### Values

- **Correctness** - Software that is proven to work correctly
- **Type Safety** - Leveraging Haskell's type system to prevent bugs
- **Open Source** - Transparent, community-driven development
- **Quality** - High standards for code, tests, and documentation
- **Collaboration** - Welcoming contributors from all backgrounds

## Roles and Responsibilities

### Users

People who use Surypus. They provide feedback, report bugs, and suggest features.

**Responsibilities:**
- Report bugs and issues
- Suggest improvements
- Provide feedback
- Contribute to documentation

### Contributors

People who contribute code, documentation, or other improvements.

**Responsibilities:**
- Follow the Code of Conduct
- Submit quality contributions
- Participate in code reviews
- Help other contributors

### Maintainers

People who have commit access and are responsible for the project direction.

**Current Maintainers:**
- [@dominicusin](https://github.com/dominicusin) - Project lead

**Responsibilities:**
- Review and merge pull requests
- Set project direction and priorities
- Manage releases
- Mentor new contributors
- Enforce the Code of Conduct
- Maintain project infrastructure

### Core Team

Experienced contributors who have demonstrated commitment to the project.

**Responsibilities:**
- Provide architectural guidance
- Review complex changes
- Mentor maintainers
- Make decisions on project direction

## Decision Making

### Consensus-Based Decision Making

We use a consensus-based approach to decision making:

1. **Proposals** are made via GitHub Issues or Discussions
2. **Discussion** happens in the open for transparency
3. **Consensus** is sought among maintainers
4. **Decisions** are documented in the issue/discussion

### Types of Decisions

#### Routine Decisions

- Bug fixes and minor improvements
- Documentation updates
- Test additions
- Dependency updates (patch/minor)

**Process:** Contributor submits PR, maintainer reviews and merges.

#### Significant Decisions

- New features
- API changes
- Architecture changes
- New dependencies

**Process:** Open a Discussion, gather feedback, create RFC if needed, implement after consensus.

#### Strategic Decisions

- Project direction
- Major refactoring
- Breaking changes
- Governance changes

**Process:** RFC (Request for Comments) process, community input, core team decision.

### RFC Process

For significant architectural decisions, we use Architecture Decision Records (ADRs):

1. **Create ADR** in `docs/adr/`
2. **Discuss** in a GitHub Issue
3. **Gather feedback** from community
4. **Make decision** based on consensus
5. **Implement** the decision
6. **Document** the outcome

## Contribution Process

### Getting Started

1. Read [CONTRIBUTING.md](CONTRIBUTING.md)
2. Set up development environment
3. Look for [good first issues](../../labels/good%20%first%20issue)
4. Join the community discussions

### Making Contributions

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Write tests
5. Update documentation
6. Submit a pull request

### Code Review Process

1. All PRs require at least 1 approval from a maintainer
2. Automated checks must pass
3. Code review follows [CODE_REVIEW_GUIDELINES.md](CODE_REVIEW_GUIDELINES.md)
4. Changes are merged using squash merge

### Recognition

Contributors are recognized in:

- Release notes for significant contributions
- GitHub contributors page
- Project documentation

## Release Process

### Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions
- **PATCH** version for backwards-compatible bug fixes

### Release Schedule

- **Patch releases** - As needed for bug fixes
- **Minor releases** - Monthly for new features
- **Major releases** - As needed for breaking changes

### Release Checklist

1. All tests pass
2. Documentation is up to date
3. CHANGELOG.md is updated
4. Version number is bumped
5. Git tag is created
6. GitHub Release is published
7. Hackage package is uploaded (if applicable)
8. Docker image is built and pushed

## Code of Conduct

All participants are expected to follow our [Code of Conduct](CODE_OF_CONDUCT.md). Violations will be addressed by the maintainers.

## License

Surypus is licensed under the [Mozilla Public License 2.0](LICENSE).

### Why MPL-2.0?

- **File-level copyleft** - Changes to Surypus files must be shared
- **Compatible with proprietary code** - Can be used in proprietary projects
- **Patent protection** - Explicit patent grant from contributors
- **Simpler than GPL** - Less restrictive for commercial use

## Communication

### Channels

- **GitHub Issues** - Bug reports and feature requests
- **GitHub Discussions** - Questions and ideas
- **GitHub Wiki** - Documentation and guides

### Response Times

- **Bug reports** - Acknowledged within 48 hours
- **Feature requests** - Discussed within 1 week
- **Pull requests** - Reviewed within 48 hours
- **Security issues** - Addressed immediately

## Project Infrastructure

### Repository

- **Main repository:** https://github.com/surypus/surypus
- **License:** MPL-2.0
- **Branch protection:** Enabled for `main`

### CI/CD

- **GitHub Actions** for continuous integration
- **61+ workflows** for comprehensive automation
- **Automated testing** on every PR
- **Automated security scanning**

### Documentation

- **README.md** - Project overview
- **CONTRIBUTING.md** - Contribution guidelines
- **CODE_OF_CONDUCT.md** - Community standards
- **SECURITY.md** - Security policy
- **CHANGELOG.md** - Version history
- **docs/** - Detailed documentation

## Amendments

This governance document may be amended by the maintainers. Significant changes will be discussed with the community before implementation.

---

*Last updated: 2026-09-03*
