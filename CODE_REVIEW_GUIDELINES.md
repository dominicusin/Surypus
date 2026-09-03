# Code Review Guidelines

This document provides guidelines for code reviewers to ensure quality, consistency, and constructive feedback.

## Table of Contents

- [Purpose](#purpose)
- [What to Review](#what-to-review)
- [How to Provide Feedback](#how-to-provide-feedback)
- [Review Checklist](#review-checklist)
- [Common Issues to Watch For](#common-issues-to-watch-for)
- [Review Etiquette](#review-etiquette)

## Purpose

Code reviews serve multiple purposes:

- **Catch bugs** before they reach production
- **Share knowledge** across the team
- **Maintain code quality** and consistency
- **Mentor** new contributors
- **Document** design decisions

## What to Review

### Functionality

- Does the code do what it's supposed to do?
- Are edge cases handled?
- Are error conditions properly managed?
- Are there any race conditions or concurrency issues?

### Design

- Is the code well-structured and maintainable?
- Does it follow SOLID principles?
- Are abstractions appropriate?
- Is the code testable?

### Readability

- Is the code self-documenting?
- Are names clear and meaningful?
- Are functions small and focused?
- Is the code easy to understand?

### Security

- Are inputs validated?
- Are secrets properly handled?
- Are there any injection vulnerabilities?
- Is authentication/authorization correct?

### Performance

- Are there any obvious performance issues?
- Are database queries efficient?
- Are resources properly managed?
- Are there any memory leaks?

## How to Provide Feedback

### Use Conventional Comments

We use [Conventional Comments](https://conventionalcomments.org/) for clear, consistent feedback:

```
<label>: <comment>
```

### Labels

| Label | Meaning | Action Required |
|-------|---------|-----------------|
| **nit** | Minor suggestion | Optional, non-blocking |
| **question** | Needs clarification | Discussion needed |
| **issue** | Must be addressed | Blocking |
| **praise** | Highlight good practices | None |
| **suggestion** | Alternative approach | Consider, non-blocking |
| **todo** | Future improvement | Track separately |
| **blocker** | Critical issue | Must fix before merge |

### Examples

**Praise:**
```
praise: Excellent use of LiquidHaskell refinements here. This makes the invariant explicit and machine-checkable.
```

**Nit:**
```
nit: Consider renaming `x` to `taxRate` for clarity.
```

**Question:**
```
question: Why was `Int64` chosen here instead of `Int`? Is this for database compatibility?
```

**Issue:**
```
issue: This function doesn't handle the case where `taxRate` is negative. Please add validation.
```

**Suggestion:**
```
suggestion: Consider using `Maybe` here instead of throwing an error. This would make the failure case explicit in the type.
```

**Blocker:**
```
blocker: This introduces a SQL injection vulnerability. Please use parameterized queries.
```

## Review Checklist

### General

- [ ] Code compiles without warnings
- [ ] Tests pass locally
- [ ] New tests added for new functionality
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] No breaking changes (or documented)

### Haskell-Specific

- [ ] Follows Haskell2010 standard
- [ ] Uses explicit imports (no wildcards)
- [ ] Haddock comments for public functions
- [ ] No partial functions (use `Maybe`/`Either`)
- [ ] Proper error handling
- [ ] No unnecessary `IO` in pure functions
- [ ] Uses appropriate data structures
- [ ] Follows project naming conventions

### Security

- [ ] No hardcoded secrets
- [ ] Inputs validated at boundaries
- [ ] Database queries use parameterized statements
- [ ] Authentication/authorization checked
- [ ] No sensitive data logged

### Performance

- [ ] No unnecessary database queries
- [ ] Lazy vs strict evaluation considered
- [ ] Resources properly cleaned up
- [ ] No obvious bottlenecks

## Common Issues to Watch For

### Haskell Anti-Patterns

- **Partial functions**: `head`, `tail`, `fromJust` on potentially empty lists
- **Unnecessary IO**: Performing IO in pure functions
- **String type**: Using `String` instead of `Text` for user data
- **Missing error handling**: Not handling `Maybe`/`Either` cases
- **Poor naming**: Single-letter variables in non-trivial functions

### Security Issues

- **SQL injection**: String interpolation in queries
- **XSS**: Unescaped user input in HTML
- **Hardcoded secrets**: API keys, passwords in code
- **Missing auth**: Endpoints without authentication
- **Information leakage**: Detailed error messages to users

### Performance Issues

- **N+1 queries**: Multiple database queries in loops
- **Unnecessary work**: Redundant computations
- **Memory leaks**: Unbounded data structures
- **Blocking operations**: Long-running operations on main thread

## Review Etiquette

### For Reviewers

1. **Be respectful** - Critique code, not people
2. **Be specific** - Point to exact lines and suggest alternatives
3. **Be timely** - Review within 48 hours
4. **Be thorough** - Don't just skim, understand the changes
5. **Be open** - Accept that there are multiple valid approaches
6. **Be constructive** - Explain why something should change

### For Authors

1. **Be receptive** - Accept feedback graciously
2. **Be responsive** - Address comments within 7 days
3. **Be clear** - Explain your reasoning in PR description
4. **Be patient** - Reviewers are helping improve your code
5. **Be willing** - To refactor if needed

### Resolving Disagreements

1. **Discuss in PR** - Use comments to explain perspectives
2. **Provide examples** - Show code that demonstrates your point
3. **Seek consensus** - Find a solution both parties can accept
4. **Escalate if needed** - Ask a third reviewer for input
5. **Document decisions** - Add comments explaining why a approach was chosen

## Approval Process

### Required Approvals

- **1 approval** from a maintainer for most changes
- **2 approvals** for breaking changes
- **Security team approval** for security-related changes

### Auto-Approval Criteria

PRs may be auto-approved if:

- Documentation-only changes
- Test-only changes (no functional code)
- Dependency version bumps (patch/minor)
- CI/CD configuration changes

### Emergency Procedures

For urgent security fixes:

1. Mark PR as **urgent**
2. Tag maintainers directly
3. Use **hotfix/** branch prefix
4. Expedited review process
