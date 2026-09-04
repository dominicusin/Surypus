# Security Checklist for PRs

This checklist helps ensure security is considered in every pull request.

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
---Thank you for helping keep Surypus secure!
<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

---

## Why Security Reviews Matter

Security vulnerabilities can be introduced in any change, no matter how small. This checklist helps catch common issues before they reach production.

**For Contributors:** Use this checklist before submitting your PR.

**For Reviewers:** Use this checklist when reviewing PRs.

---

## Security Checklist

### Secrets & Credentials

- [ ] No API keys, tokens, passwords, or other secrets in code
- [ ] No sensitive configuration in source files
- [ ] Environment variables used for sensitive values
- [ ] Secrets stored in GitHub Secrets (not in workflow files)

### Input Validation

- [ ] All user input validated
- [ ] Input validation at API/CLI boundaries
- [ ] Strong types used where possible
- [ ] Invalid input rejected early
- [ ] No trust in client-side validation alone

### Authentication & Authorization

- [ ] Authentication checks present where needed
- [ ] Authorization checks on every request
- [ ] No authentication bypasses
- [ ] Session management secure
- [ ] Password handling secure (hashing, not plaintext)

### Data Protection

- [ ] Sensitive data not logged
- [ ] PII handled according to privacy policy
- [ ] Encryption used for sensitive data at rest/transit
- [ ] Error messages don't leak sensitive information

### Dependencies

- [ ] No new dependencies without review
- [ ] Dependencies are from trusted sources
- [ ] Dependency versions pinned (not floating)
- [ ] No known vulnerabilities in dependencies
- [ ] Unused dependencies removed

### Code Quality

- [ ] No SQL injection risks (parameterized queries)
- [ ] No command injection risks
- [ ] No XSS vulnerabilities (output escaping)
- [ ] No path traversal risks
- [ ] No race conditions (proper synchronization)

### Error Handling

- [ ] Errors handled gracefully
- [ ] No sensitive information in error messages
- [ ] Proper error responses (no stack traces to users)
- [ ] Errors logged for debugging (without sensitive data)

### Testing

- [ ] Security-relevant tests included
- [ ] Edge cases tested
- [ ] Failure modes considered
- [ ] Tests pass

### Documentation

- [ ] Security implications documented (if any)
- [ ] Setup instructions don't expose secrets
- [ ] Configuration examples are secure by default

---

## Common Issues to Watch For

### SQL Injection

```haskell
-- BAD: String concatenation
query = "SELECT * FROM users WHERE name = '" ++ userName ++ "'"

-- GOOD: Parameterized query
query = "SELECT * FROM users WHERE name = ?" [userName]
```

### XSS (Cross-Site Scripting)

```haskell
-- BAD: Unescaped output
html = "<div>" ++ userInput ++ "</div>"

-- GOOD: Escaped output
html = "<div>" ++ escapeHtml userInput ++ "</div>"
```

### Command Injection

```haskell
-- BAD: Shell command with user input
system $ "echo " ++ userInput

-- GOOD: Use safe libraries, avoid shell
-- or properly escape/validate
```

### Hardcoded Credentials

```haskell
-- BAD: Hardcoded API key
apiKey = "sk-1234567890abcdef"

-- GOOD: Environment variable
apiKey <- getEnv "API_KEY"
```

### Path Traversal

```haskell
-- BAD: User-controlled path
filePath = baseDir ++ "/" ++ userPath

-- GOOD: Validate and sanitize path
-- or use safe path manipulation libraries
```

---

## For Reviewers

### What to Look For

1. **Secrets** — Any credentials in code?
2. **Input validation** — Is all input validated?
3. **Auth checks** — Are auth boundaries respected?
4. **Data exposure** — Any sensitive data leaked?
5. **Dependencies** — Are new deps safe?
6. **Error handling** — Are errors handled securely?
7. **Testing** — Are security tests included?

### Review Questions

- Could this change be exploited?
- Does this introduce new attack surface?
- Are there any security regressions?
- Is the change consistent with security best practices?
- Should we add security tests for this?

### Handling Security Issues in PRs

1. **Point out the issue** clearly
2. **Explain the risk** if not obvious
3. **Suggest a fix** if possible
4. **Request changes** — Don't approve until fixed
5. **Escalate** if the issue is serious

---

## For Maintainers

### Merge Criteria

- [ ] All checklist items addressed
- [ ] Security review completed (if applicable)
- [ ] No high/critical security issues
- [ ] Security tests pass

### Post-Merge

- [ ] Monitor for security issues
- [ ] Update dependencies if needed
- [ ] Document any security considerations

---

## Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [GitHub Security Lab](https://securitylab.github.com/)
- [Haskell Security Guidelines](https://haskell.org/security)
- [Surypus Security Policy](SECURITY.md)

---

*Remember: Security is everyone's responsibility. When in doubt, ask!*