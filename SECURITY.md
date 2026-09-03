# Security Policy

## Supported Versions

We actively maintain the following versions:

| Version | Supported | Description |
|---------|-----------|-------------|
| `main` | ✅ | Latest development branch |
| `v0.1.x` | ✅ | Current stable release |
| `< v0.1` | ❌ | No longer supported |

## Reporting a Vulnerability

### How to Report

**Please do NOT open a public issue for security vulnerabilities.**

Instead, report privately via one of these methods:

1. **GitHub Security Advisories** (preferred):
   - Go to [Security → Advisories](https://github.com/surypus/surypus/security/advisories/new)
   - Click "Draft a new advisory"
   - Fill in the details

2. **Private message** to maintainers (if advisories are not available)

### What to Include

- **Description** of the vulnerability
- **Steps to reproduce** the issue
- **Impact** assessment (what could be exploited)
- **Suggested fix** (if you have one)
- **Your contact** for follow-up

### Response Timeline

| Action | Timeline |
|--------|----------|
| Initial response | Within 48 hours |
| Investigation complete | Within 7 days |
| Fix released | Within 30 days (critical: 7 days) |
| Public disclosure | After fix is available |

## Security Measures

### Automated Security

- **Secret scanning** - Detects accidentally committed secrets
- **Push protection** - Blocks commits containing secrets
- **Dependabot alerts** - Notifies of vulnerable dependencies
- **Dependabot security updates** - Auto-fixes vulnerable dependencies
- **CodeQL analysis** - Static analysis for security vulnerabilities
- **SBOM generation** - Software Bill of Materials for supply chain security

### Manual Security

- **Code review** - All PRs reviewed by maintainers
- **Security hardening** - Weekly security scans
- **Supply chain security** - Dependency audit
- **Security advisory automation** - Weekly security reports

## Security Best Practices for Contributors

### DO

- ✅ Validate all inputs at API boundaries
- ✅ Use parameterized queries (no SQL injection)
- ✅ Hash passwords with bcrypt
- ✅ Use HTTPS for all communications
- ✅ Keep dependencies up to date
- ✅ Report vulnerabilities privately
- ✅ Follow principle of least privilege

### DON'T

- ❌ Commit secrets (API keys, passwords, tokens)
- ❌ Log sensitive data
- ❌ Trust user input without validation
- ❌ Use deprecated or vulnerable dependencies
- ❌ Bypass authentication/authorization checks
- ❌ Expose internal error messages to users

## Security Checklist for PRs

- [ ] No hardcoded secrets
- [ ] Inputs validated
- [ ] Database queries use parameterized statements
- [ ] Authentication/authorization checked
- [ ] No sensitive data logged
- [ ] Error messages don't leak information
- [ ] Dependencies are up to date

## Security Contacts

- **Project maintainers**: [@dominicusin](https://github.com/dominicusin)
- **GitHub Security Advisories**: [Create advisory](https://github.com/surypus/surypus/security/advisories/new)

## Disclosure Policy

We follow responsible disclosure:

1. **Private report** - Reporter submits vulnerability privately
2. **Investigation** - Maintainers investigate and confirm
3. **Fix** - Maintainers develop and test a fix
4. **Release** - Fix is released to production
5. **Disclosure** - Public disclosure after fix is available
6. **Credit** - Reporter is credited (with permission)

## Security Acknowledgments

We thank the following security researchers for their contributions:

- (No reports yet - be the first!)

---

*Last updated: 2026-09-03*
