# Security Policy

This document describes how Surypus handles security vulnerabilities and how to report them.

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
---Thank you to all the security researchers who help keep Surypus safe!
<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

---

## Supported Versions

We actively maintain the following versions:

| Version | Supported | Description |
|---------|-----------|-------------|
| `main` | ✅ | Latest development branch |
| `v56.0` | ✅ | Current stable release |
| `< v56.0` | ❌ | No longer supported |

## Reporting a Vulnerability

**Please do NOT open a public issue for security vulnerabilities.**

Instead, report privately via one of these methods:

### 1. GitHub Security Advisories (Preferred)

1. Go to [Security → Advisories](https://github.com/surypus/surypus/security/advisories/new)
2. Click "Draft a new advisory"
3. Fill in the details (description, severity, affected versions)
4. Submit — this creates a private report visible only to maintainers

GitHub will automatically create a private fork for developing fixes and a draft security advisory. Everything remains confidential until you decide to disclose.

### 2. Email to Security Team

Send to **security@surypus.dev** with subject line:

```
[SECURITY] Vulnerability in Surypus
```

Include:
- Description of the vulnerability
- Steps to reproduce the issue
- Impact assessment (what could be exploited)
- Suggested fix (if you have one)
- Your contact information for follow-up

### 3. Private Message to Maintainers

If the above methods are not available, you can send a private message to [@dominicusin](https://github.com/dominicusin) on GitHub.

---

## What to Include in Your Report

To help us investigate and fix the issue quickly, please include:

| Item | Description |
|------|-------------|
| **Description** | Clear description of the vulnerability |
| **Steps to reproduce** | Detailed steps to trigger the issue |
| **Impact** | What could be exploited, who is affected |
| **Affected versions** | Which versions are affected |
| **Suggested fix** | Your ideas for remediation (optional) |
| **Contact** | How we can reach you for follow-up |

---

## Response Timeline

We aim to respond promptly to security reports:

| Stage | Timeline |
|-------|----------|
| **Initial response** | Within 48 hours |
| **Acknowledgment** | Within 24 hours |
| **Investigation complete** | Within 7 days |
| **Fix developed** | Within 14 days (critical: 3 days) |
| **Fix released** | Within 30 days (critical: 7 days) |
| **Public disclosure** | After fix is available |

If we need more time, we will communicate with you.

---

## Security Measures

### Automated Security

| Measure | Description |
|---------|-------------|
| **Secret scanning** | Detects accidentally committed secrets |
| **Push protection** | Blocks commits containing secrets |
| **Dependabot alerts** | Notifies of vulnerable dependencies |
| **Dependabot security updates** | Auto-fixes vulnerable dependencies |
| **CodeQL analysis** | Static analysis for security vulnerabilities |
| **SBOM generation** | Software Bill of Materials for supply chain security |
| **Weekly security scans** | Comprehensive automated checks |

### Manual Security

| Measure | Description |
|---------|-------------|
| **Code review** | All PRs reviewed by maintainers |
| **Security hardening** | Weekly security hardening reviews |
| **Supply chain security** | Dependency audit and verification |
| **Security advisory automation** | Weekly security reports |

### Security Best Practices

#### For Contributors

**DO:**
- ✅ Validate all inputs at API boundaries
- ✅ Use parameterized queries (no SQL injection)
- ✅ Hash passwords with bcrypt or similar
- ✅ Use HTTPS for all communications
- ✅ Keep dependencies up to date
- ✅ Report vulnerabilities privately
- ✅ Follow principle of least privilege

**DON'T:**
- ❌ Commit secrets (API keys, passwords, tokens)
- ❌ Log sensitive data
- ❌ Trust user input without validation
- ❌ Use deprecated or vulnerable dependencies
- ❌ Bypass authentication/authorization checks
- ❌ Expose internal error messages to users

#### For Maintainers

- Conduct regular security reviews
- Keep dependencies updated
- Review and triage security alerts promptly
- Maintain security documentation
- Coordinate vulnerability disclosure
- Publish security advisories

---

## Security Checklist for Pull Requests

Before merging, verify:

- [ ] No hardcoded secrets
- [ ] Inputs are validated
- [ ] Database queries use parameterized statements
- [ ] Authentication/authorization checked
- [ ] No sensitive data logged
- [ ] Error messages don't leak information
- [ ] Dependencies are up to date
- [ ] Security tests pass (if applicable)

See [CONTRIBUTING_SECURITY_CHECKLIST.md](CONTRIBUTING_SECURITY_CHECKLIST.md) for detailed checklist.

---

## Security Advisories

We publish security advisories for disclosed vulnerabilities:

- **GitHub Advisories**: [View advisories](https://github.com/surypus/surypus/security/advisories)
- **Advisory format**: Follows [CVE](https://cve.mitre.org/) conventions where applicable

When we publish an advisory, we include:
- Vulnerability description
- Affected versions
- Fixed versions
- References (CVE ID if assigned)
- Credit to reporter (with permission)

---

## Disclosure Policy

We follow a **coordinated disclosure** process:

1. **Report received** — We acknowledge within 48 hours
2. **Investigation** — We investigate and confirm the issue
3. **Fix development** — We develop and test a fix
4. **Internal review** — We verify the fix
5. **Release** — We release the fix
6. **Disclosure** — We publish the advisory after the fix is available

For critical vulnerabilities, we may adjust timelines.

---

## Security Team

| Role | Contact |
|------|---------|
| **Security Lead** | [@dominicusin](https://github.com/dominicusin) |
| **Security Email** | [security@surypus.dev](mailto:security@surypus.dev) |
| **GitHub Advisories** | [Create advisory](https://github.com/surypus/surypus/security/advisories/new) |

---

## Additional Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [GitHub Security Lab](https://securitylab.github.com/)
- [Haskell Security Guidelines](https://www.haskell.org/security/)
- [NIST Secure Coding Guidelines](https://www.nist.gov/itl/ssd/software-quality-group/secure-coding-guidelines)

---

*Last updated: 2026-09-04*

*Surypus takes security seriously. If you have questions about this policy, reach out to the maintainers.*
