# Safe Participation & Security Guide

This document outlines security best practices and safe participation guidelines for the Surypus project.

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
---
Thank you to all the contributors who keep Surypus safe and secure!
<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

---

## Security Overview

Surypus employs multiple layers of security to protect against vulnerabilities:

1. **Code-level security** — Type safety, formal verification, input validation
2. **Dependency security** — Automated scanning and updates
3. **Infrastructure security** — Secure CI/CD, protected branches
4. **Process security** — Code review, security policies, incident response

### Key Security Principles

| Principle | Description |
|-----------|-------------|
| **Defense in Depth** | Multiple layers of security controls |
| **Least Privilege** | Minimum permissions needed for each component |
| **Fail Secure** | Failures default to secure state |
| **Secure by Default** | Safe configurations out of the box |
| **Auditability** | All security-relevant actions are logged |

---

## Secure Development Practices

### Input Validation

**Always validate all external input:**

```haskell
-- GOOD: Validate at API boundary
validateInput :: Input -> Either ValidationError ValidatedInput
validateInput = ...

-- Process only validated input
process :: ValidatedInput -> Result
process = ...
```

**Key rules:**
- Validate at entry points (API, CLI, file upload)
- Use strong types to encode constraints
- Reject invalid input early
- Never trust data from external sources

### Authentication & Authorization

**Authentication:**
- Use established libraries (e.g., `auth`, `haskell-auth`)
- Hash passwords with bcrypt/argon2
- Use secure session management
- Implement MFA where appropriate

**Authorization:**
- Check permissions on every request
- Implement role-based access control (RBAC)
- Principle of least privilege
- Log authorization decisions

### Data Protection

**Encryption:**
- Encrypt sensitive data at rest
- Use TLS for all communications
- Manage encryption keys securely (key rotation, secure storage)

**Logging:**
- Never log passwords, tokens, PII
- Sanitize log output
- Implement log rotation
- Secure log storage

### Secure Dependencies

- Keep dependencies updated
- Use Dependabot for automated alerts
- Review dependencies before adding
- Pin dependency versions
- Monitor for supply chain attacks

---

## Static Analysis & SAST

### CodeQL Integration

We use CodeQL for static analysis:

- **Automated scanning** on every push and PR
- **Security queries** for common vulnerability patterns
- **Integration with GitHub Security tab**
- **Weekly scheduled scans**

### SAST Best Practices

1. **Run SAST early** — Integrate into development workflow
2. **Review findings** — Don't ignore alerts
3. **Fix high-severity issues** — Prioritize based on severity
4. **Prevent regressions** — Add tests for fixed issues
5. **Tune rules** — Reduce false positives over time

### Static Analysis Checklist

- [ ] CodeQL configured and running
- [ ] Security queries enabled
- [ ] PRs blocked on security scan failures
- [ ] Weekly scans scheduled
- [ ] Findings reviewed and triaged

---

## Dependency Security

### Dependabot Configuration

```yaml
version: 2
updates:
  - package-ecosystem: "stack"
    directory: "/"
    schedule:
      interval: "daily"
    open-pull-requests-limit: 10
    labels:
      - "dependencies"
      - "automated"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "daily"
    labels:
      - "dependencies"
      - "ci"
```

### Dependency Review

**Before adding a dependency:**
- Check reputation and maintenance status
- Review security history
- Check license compatibility
- Evaluate necessity (do you really need it?)
- Consider smaller alternatives

**Ongoing:**
- Monitor Dependabot alerts
- Update promptly for security patches
- Remove unused dependencies
- Review dependency changes in PRs

### Supply Chain Security

- **Verified sources** — Download from official sources
- **Checksum verification** — Verify package integrity
- **Signature verification** — When available
- **Trusted publishers** — Use verified publisher program
- **SBOM generation** — Track dependencies

---

## Secret Management

### Never Commit Secrets

**DO NOT put these in code:**
- API keys
- Database passwords
- Access tokens
- Private keys
- Encryption keys
- Any sensitive credentials

**Use environment variables:**

```bash
# .env file (gitignored)
DATABASE_URL=postgresql://user:pass@host/db
API_KEY=sk-...

# In code
import System.Environment (getEnv)
dbUrl <- getEnv "DATABASE_URL"
```

### GitHub Secrets

For CI/CD:
- Store secrets in GitHub repository settings
- Access via `${{ secrets.NAME }}` in workflows
- Use secrets in GitHub Actions only
- Never echo secrets in logs

### Secret Scanning

- **Push protection** blocks commits with secrets
- **Secret scanning** detects leaked secrets
- **Rotate immediately** if a secret is exposed
- **Report exposure** to maintainers

---

## CI/CD Security

### Secure Workflow Configuration

```yaml
# GOOD: Pin action versions
uses: actions/checkout@v4
uses: haskell-actions/setup@v2

# BAD: Avoid floating tags
uses: actions/checkout@main  # Don't do this!
```

### Workflow Permissions

- **Least privilege** — Grant only needed permissions
- **Avoid `permissions: write-all`**
- **Use fine-grained permissions**

```yaml
permissions:
  contents: read
  issues: write
  # Avoid: contents: write unless needed
```

### Secure Build Environment

- Use official base images
- Keep build environment updated
- Don't use privileged containers
- Limit network access in builds
- Use build secrets management

---

## Incident Response

### Security Incident Process

1. **Identify** — Detect the incident
2. **Contain** — Stop the damage
3. **Eradicate** — Remove the cause
4. **Recover** — Restore normal operation
5. **Learn** — Improve processes

### Reporting Security Issues

**For security vulnerabilities:**
- Follow [SECURITY.md](SECURITY.md) reporting process
- Use private reporting channels
- Coordinate disclosure timeline

**For security incidents:**
- Immediately notify maintainers
- Document what happened
- Preserve evidence
- Follow incident response plan

---

## Security Testing

### Types of Security Testing

| Type | Description | Frequency |
|------|-------------|-----------|
| Static Analysis (SAST) | Code analysis without execution | Every PR |
| Dependency Scanning | Check dependencies for vulnerabilities | Daily |
| Dynamic Analysis (DAST) | Test running application | Periodically |
| Penetration Testing | Simulated attacks | Annually/major releases |
| Code Review | Manual security review | Every PR |

### Security Test Checklist

- [ ] SAST scans pass
- [ ] No high/critical vulnerabilities
- [ ] Dependencies are current
- [ ] Security tests included in test suite
- [ ] Penetration test results reviewed

---

## Additional Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [GitHub Security Lab](https://securitylab.github.com/)
- [Haskell Security Guidelines](https://haskell.org/security)
- [NIST Secure Coding Guidelines](https://www.nist.gov/itl/ssd/software-quality-group/secure-coding-guidelines)

---

*Last updated: 2026-09-04*
