# CodeQL Static Analysis

This document describes the CodeQL static analysis setup for Surypus.

## What is CodeQL?

CodeQL is a semantic code analysis engine that treats code as data. It identifies security vulnerabilities and coding errors by querying the code database.

## Setup

### GitHub Actions Workflow

We use CodeQL via GitHub Actions:

- **File**: `.github/workflows/codeql.yml`
- **Triggers**:
  - Push to `main` branch
  - Pull requests to `main`
  - Scheduled: Weekly on Thursday at 1:30 AM UTC

### Languages Analyzed

| Language | Status | Notes |
|----------|--------|-------|
| Haskell | ✅ Community queries | Community-maintained queries |
| Python | ✅ Built-in | Built-in queries |
| JavaScript | ✅ Built-in | Built-in queries |

### CodeQL Configuration

```yaml
# In .github/workflows/codeql.yml
language: ${{ matrix.language }}
```

CodeQL automatically:
- Builds the codebase
- Extracts data from the code
- Runs security queries
- Reports findings to the Security tab

## Viewing Results

### GitHub Security Tab

Results appear in:
- **Security → Code scanning alerts**
- Filterable by severity, language, category

### Severity Levels

| Severity | Description | Action |
|----------|-------------|--------|
| **Critical** | Exploitable vulnerability | Fix immediately |
| **High** | Likely exploitable | Fix soon |
| **Medium** | May be exploitable | Fix when possible |
| **Low** | Minor issue | Fix when convenient |
| **Note** | Informational | Consider fixing |

## Query Suites

CodeQL includes many built-in query suites:

### Security Queries

- **Security/extensive** — Comprehensive security analysis
- **Security and quality** — Security + code quality
- **Security** — Basic security checks

### Quality Queries

- **Code quality** — Code style and maintainability
- **Error handling** — Error handling patterns

## Custom Queries

For Haskell-specific analysis, we can add custom queries:

```yaml
# Example: Custom query pack
- name: Initialize CodeQL
  uses: github/codeql-action/init@v3
  with:
    languages: haskell
    queries: ./codeql-queries
```

## Managing Alerts

### Triage Process

1. **Review alert** — Understand the finding
2. **Determine validity** — Is it a true positive?
3. **Assess severity** — How serious is it?
4. **Fix or dismiss** — Fix if valid, explain if false positive
5. **Add test** — Prevent regression

### Dismissing Alerts

If an alert is a false positive:

1. Click "Dismiss" on the alert
2. Select reason (e.g., "Won't fix", "False positive")
3. Add explanation

### Fixing Alerts

1. Understand the issue
2. Make the fix
3. Test the fix
4. Verify CodeQL no longer reports it
5. Explain the fix in commit message

## Integration with CI

CodeQL runs in CI and can block PRs:

- **Security alerts cause PR check failure**
- **Review required before merge**
- **Can be overridden for non-security issues**

## Limitations

- **Haskell support** — Community-maintained, may lag behind
- **False positives** — Some alerts may be invalid
- **Coverage** — Not all code paths analyzed
- **Language features** — Complex Haskell features may not be fully analyzed

## Best Practices

1. **Run on every PR** — Catch issues early
2. **Review weekly** — Don't let alerts pile up
3. **Fix high/critical first** — Prioritize by severity
4. **Document fixes** — Explain what was changed and why
5. **Add tests** — Prevent regression

## Resources

- [CodeQL Documentation](https://codeql.github.com/docs/)
- [CodeQL GitHub Action](https://github.com/github/codeql-action)
- [CodeQL Query Help](https://codeql.github.com/docs/codeql-queries/)
- [GitHub Security Lab](https://securitylab.github.com/)

---

*Last updated: 2026-09-04*
