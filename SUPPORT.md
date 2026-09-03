# Support

Need help with Surypus? This document describes how to get support.

## Table of Contents

- [Getting Help](#getting-help)
- [Documentation](#documentation)
- [Community Support](#community-support)
- [Commercial Support](#commercial-support)
- [Response Times](#response-times)
- [How to Ask for Help](#how-to-ask-for-help)

## Getting Help

### Quick Questions

- **GitHub Discussions** - [Ask a question](https://github.com/surypus/surypus/discussions)
- **Stack Overflow** - Ask with the `surypus` tag

### Bug Reports

- **GitHub Issues** - [Report a bug](https://github.com/surypus/surypus/issues/new?template=bug_report.yml)

### Feature Requests

- **GitHub Issues** - [Request a Feature](https://github.com/surypus/surypus/issues/new?template=feature_request.yml)

### Security Issues

- **GitHub Security Advisories** - [Report Security Issue](https://github.com/surypus/surypus/security/advisories/new)

## Documentation

- [README.md](README.md) - Project overview
- [CONTRIBUTING.md](CONTRIBUTING.md) - How to contribute
- [CHANGELOG.md](CHANGELOG.md) - Version history
- [API Documentation](API_DOCUMENTATION.md) - API reference
- [Architecture](docs/architecture/ARCHITECTURE.md) - System architecture
- [Wiki](https://github.com/surypus/surypus/wiki) - Community documentation

## Community Support

### GitHub Discussions

For general questions, ideas, and discussions, use [GitHub Discussions](https://github.com/surypus/surypus/discussions).

### Stack Overflow

For technical questions, ask on [Stack Overflow](https://stackoverflow.com/questions/tagged/surypus) with the `surypus` tag.

### Social Media

- **Twitter** - [@surypus](https://twitter.com/surypus) (coming soon)
- **Discord** - [Join our server](https://discord.gg/surypus) (coming soon)

## Commercial Support

For commercial support, consulting, or custom development, please contact the maintainers.

## Response Times

| Type | Expected Response |
|------|-------------------|
| Security issues | Within 24 hours |
| Bug reports | Within 48 hours |
| Feature requests | Within 1 week |
| Pull requests | Within 48 hours |
| Questions | Within 1 week |

## How to Ask for Help

### Before Asking

1. **Search existing issues** - Your question may already be answered
2. **Read the documentation** - Check the docs first
3. **Try to reproduce** - Create a minimal example that demonstrates the issue

### When Asking

1. **Be clear and concise** - Describe the problem clearly
2. **Provide context** - Include your environment, versions, and steps to reproduce
3. **Include code** - Share relevant code snippets
4. **Be respectful** - Remember that maintainers are volunteers

### Example: Good Bug Report

```
Title: VAT calculation returns incorrect result for reverse charge

Description:
When calculating VAT for reverse charge transactions, the result is incorrect.

Steps to reproduce:
1. Create a bill with reverse charge enabled
2. Calculate VAT
3. The result is 0 instead of the expected amount

Expected: VAT should be calculated correctly
Actual: VAT is 0

Environment:
- GHC 9.6.6
- Stack 2.13
- PostgreSQL 14
```

---

*We're here to help! Don't hesitate to reach out.*
