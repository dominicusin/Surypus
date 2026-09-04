# Security Best Practices for Surypus

This document outlines security best practices for contributors and maintainers of the Surypus project.

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
---
Thank you to all the contributors who help keep Surypus secure.
<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

---

## Overview

Security is a shared responsibility. This document covers:

1. **Code Security** — Writing secure code, SAST tools
2. **Dependency Security** — Managing dependencies safely
3. **Secret Management** — Protecting credentials
4. **Access Control** — Managing permissions
5. **Incident Response** — Handling security issues

---

## Code Security

### Input Validation

Always validate and sanitize all external input:

```haskell
-- GOOD: Validate at entry points
validateInput :: Input -> Either ValidationError ValidatedInput
validateInput = ...

-- Process only validated data
process :: ValidatedInput -> Result
process = ...
```

**Key rules:**
- Validate at API boundaries (HTTP endpoints, CLI arguments, file uploads)
- Use strong types to encode constraints
- Reject invalid input early
- Never trust data from external sources

### Authentication & Authorization

- **Authentication**: Verify identity using established libraries
- **Authorization**: Check permissions on every request
- **Session management**: Use secure session handling
- **Password storage**: Hash passwords with bcrypt/argon2

### Data Protection

- **Encryption at rest**: Encrypt sensitive data in database/storage
- **Encryption in transit**: Use TLS for all network communication
- **Logging**: Never log passwords, tokens, PII
- **Error handling**: Don't expose internal details in errors

### Common Vulnerabilities

| Vulnerability | Prevention |
|---------------|------------|
| **SQL Injection** | Use parameterized queries, never string concatenation |
| **XSS** | Escape output, use Content-Security-Policy |
| **CSRF** | Use anti-CSRF tokens, SameSite cookies |
| **Command Injection** | Avoid shell execution, use safe APIs |
| **Path Traversal** | Validate and sanitize file paths |

---

## SAST (Static Application Security Testing)

### CodeQL Integration

We use CodeQL for static analysis:

- **Workflow**: `.github/workflows/codeql.yml`
- **Schedule**: Weekly on Thursday
- **On PR**: Runs on every pull request

**Languages analyzed:**
- Haskell (via community queries)
- Python (if applicable)
- JavaScript/TypeScript (if applicable)

### Running CodeQL Locally

```bash
# Use CodeQL CLI
codeql database create --language=haskell db
codeql query run --database=db --queries=Security.qql
```

### Interpreting Results

- Review alerts in GitHub Security tab
- Triage by severity: Critical > High > Medium > Low
- Fix or dismiss false positives
- Add tests to prevent regression

### Adding Custom Queries

For Haskell-specific analysis, create custom queries in `.github/codeql-queries/`.

---

## Dependency Security

### Dependabot Configuration

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "stack"
    directory: "/"
    schedule:
      interval: "daily"
    open-pull-requests-limit: 10

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "daily"
```

### Dependency Review Process

1. **Before adding**: Check reputation, maintenance, vulnerabilities
2. **On update**: Review changelog, breaking changes
3. **On alert**: Update promptly for security patches

### Supply Chain Security

- Use verified sources for packages
- Check checksums/signatures when available
- Monitor for typosquatting attacks
- Keep SBOM updated

---

## Secret Management

### Never Commit Secrets

**Don't put in code:**
- API keys, tokens
- Database passwords
- Private keys
- Any credentials

**Use environment variables:**

```bash
# .env file (gitignored)
DATABASE_URL=postgresql://user:pass@host/db

# In code
import System.Environment (getEnv)
dbUrl <- getEnv "DATABASE_URL"
```

### GitHub Secrets

For CI/CD workflows:
- Store in repo Settings → Secrets
- Access via `${{ secrets.NAME }}`
- Never echo secrets in logs

### Secret Scanning

- **Push protection**: Blocks commits with secrets
- **Secret scanning**: Detects leaked secrets in history
- **Rotate immediately**: If secret is exposed

---

## Access Control

### Branch Protection

- `main` branch protected
- Required reviews before merge
- Status checks must pass
- No force pushes

### Required Reviews

- At least 1 approval from maintainers
- Dismiss stale reviews on new commits
- Require code owner review for critical files

### Two-Factor Authentication (2FA)

**All maintainers must enable 2FA:**

1. Go to GitHub Settings → Security
2. Enable 2FA with authentication app
3. Save recovery codes securely

**Why 2FA matters:**
- Protects against account takeover
- Required for organizatoin security
- Prevents unauthorized code changes

---

## Security Monitoring

### Automated Monitoring

| Tool | Purpose | Frequency |
|------|---------|-----------|
| CodeQL | Static analysis | Every PR + weekly |
| Dependabot | Dependency alerts | Daily |
| Secret scanning | Detect leaked secrets | Real-time |
| Security scan | Comprehensive check | Weekly |

### Security Reports

Weekly security report via automated workflow:
- `.github/workflows/security-report.yml`
- Summary of alerts, fixes, status

---

## Incident Response

### Reporting a Vulnerability

**Do NOT open public issues for security vulnerabilities.**

Report privately:
1. GitHub Security Advisories (preferred)
2. Email: security@surypus.dev
3. Private message to maintainers

### Response Process

1. **Receive** — Acknowledge within 48 hours
2. **Investigate** — Assess severity and impact
3. **Fix** — Develop and test fix
4. **Release** — Deploy fix
5. **Disclose** — Publish advisory after fix

### Severity Levels

| Level | Description | Response Time |
|-------|-------------|---------------|
| **Critical** | Remote code execution, data breach | 24-72 hours |
| **High** | Significant data exposure | 7 days |
| **Medium** | Limited impact | 30 days |
| **Low** | Minor issue | Next release |

---

## Security Checklist for PRs

- [ ] No hardcoded secrets
- [ ] Inputs validated
- [ ] Authentication/authorization checked
- [ ] No sensitive data in logs
- [ ] Error messages don't leak info
- [ ] Dependencies up to date
- [ ] Tests pass
- [ ] Security review completed (if applicable)

---

## Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [GitHub Security Lab](https://securitylab.github.com/)
- [Haskell Security Guidelines](https://www.haskell.org/security/)
- [NIST Secure Coding Guidelines](https://www.nist.gov/itl/ssd/software-quality-group/secure-coding)

---

*Last updated: 2026-09-04*
