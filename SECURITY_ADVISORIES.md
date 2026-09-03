# Security Advisories

This document describes how we handle security advisories for Surypus.

## Reporting a Vulnerability

**Please do NOT open a public issue for security vulnerabilities.**

Report privately via:

1. **GitHub Security Advisories** (preferred):
   - Go to [Security → Advisories](https://github.com/surypus/surypus/security/advisories/new)
   - Click "Draft a new advisory"
   - Fill in the details

2. **Email**: [INSERT_EMAIL]

## Advisory Lifecycle

### 1. Receive (Day 0)

- Report received via private channel
- Acknowledgment sent within 24 hours

### 2. Investigate (Day 1-3)

- Reproduce the vulnerability
- Assess severity (Critical/High/Medium/Low)
- Determine affected versions

### 3. Fix (Day 3-7)

- Develop fix
- Test fix
- Prepare security advisory

### 4. Release (Day 7-14)

- Release patched version
- Publish security advisory
- Notify users

### 5. Disclosure (Day 14+)

- Public disclosure after patch is available
- Credit reporter (with permission)

## Severity Levels

| Level | Description | Response Time |
|-------|-------------|---------------|
| Critical | Remote code execution, data loss | 24 hours |
| High | Authentication bypass, SQL injection | 48 hours |
| Medium | XSS, CSRF | 1 week |
| Low | Information disclosure | 2 weeks |

## Advisory Template

```
Title: [SEVERITY] Vulnerability in [Component]

Description:
[Brief description of the vulnerability]

Affected Versions:
- [Version range]

Patched Versions:
- [Version]

Workaround:
[If available]

Credits:
- [Reporter name]

References:
- [CVE if applicable]
```

## CVE Requests

For critical vulnerabilities, we request CVE numbers from GitHub.

---

*Last updated: 2026-09-03*
