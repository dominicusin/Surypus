# RustSec Advisory Database Anti-Patterns

This document describes common vulnerability patterns from the RustSec Advisory Database that may be relevant to similar ecosystems, including Haskell.

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
---
These patterns help us understand common vulnerability classes across ecosystems.
<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

---

## Overview

The RustSec Advisory Database catalogs security vulnerabilities in Rust crates. While Surypus is primarily Haskell, understanding these patterns helps us:

- Recognize similar vulnerability classes in our codebase
- Understand common security pitfalls across ecosystems
- Apply lessons learned from other ecosystems

---

## Common Vulnerability Patterns

### 1. Command Injection

**Pattern**: Passing unsanitized user input to shell commands

**RustSec examples:**
- RUSTSEC-2021-0001: Command injection via unsanitized input
- RUSTSEC-2022-0003: Shell command injection

**Prevention:**
- Avoid shell execution when possible
- Use safe APIs that don't invoke shell
- Validate and sanitize all input
- Use argument arrays instead of string concatenation

**Haskell equivalent:**
```haskell
-- BAD: Shell execution with user input
system $ "echo " ++ userInput

-- GOOD: Safe execution
callProcess "echo" [userInput]
```

---

### 2. SQL Injection

**Pattern**: Constructing SQL queries with string concatenation

**RustSec examples:**
- RUSTSEC-2020-0005: SQL injection via format strings

**Prevention:**
- Use parameterized queries
- Never concatenate user input into SQL strings
- Use query builders or ORM safely

**Haskell equivalent:**
```haskell
-- BAD: String concatenation
query $ "SELECT * FROM users WHERE id = " ++ show userId

-- GOOD: Parameterized query
query "SELECT * FROM users WHERE id = ?" [userId]
```

---

### 3. Path Traversal

**Pattern**: Using user input to construct file paths without validation

**RustSec examples:**
- RUSTSEC-2021-0007: Path traversal vulnerability

**Prevention:**
- Validate that resolved paths are within expected directories
- Sanitize path components
- Use safe path manipulation libraries

**Haskell equivalent:**
```haskell
-- GOOD: Validate path is within base directory
validatePath :: FilePath -> FilePath -> Either ValidationError FilePath
validatePath basePath userPath = do
    resolved <- canonicalizePath (basePath </> userPath)
    guard (resolved `isPrefixOf` basePath)
    return resolved
```

---

### 4. Deserialization Vulnerabilities

**Pattern**: Deserializing untrusted data without validation

**RustSec examples:**
- RUSTSEC-2021-0009: Untrusted deserialization

**Prevention:**
- Don't deserialize untrusted data
- Use safe serialization formats
- Validate schema before deserialization
- Limit deserialization features

---

### 5. XXE (XML External Entity)

**Pattern**: Processing XML with external entity resolution enabled

**RustSec examples:**
- RUSTSEC-2020-0011: XXE vulnerability in XML parser

**Prevention:**
- Disable external entity resolution
- Use secure XML parser configurations
- Validate XML against schema

---

### 6. Integer Overflow

**Pattern**: Not handling integer overflow in arithmetic operations

**RustSec examples:**
- RUSTSEC-2021-0013: Integer overflow in calculations

**Prevention:**
- Use checked arithmetic operations
- Validate input ranges
- Use larger integer types when needed
- Add overflow checks in critical calculations

---

### 7. Regex Denial of Service (ReDoS)

**Pattern**: Using vulnerable regex patterns that can cause catastrophic backtracking

**RustSec examples:**
- RUSTSEC-2022-0005: ReDoS vulnerability

**Prevention:**
- Use timeout for regex matching
- Avoid nested quantifiers
- Test regex with malicious input
- Use RE2-style linear-time regex engines

---

### 8. URL Parsing Vulnerabilities

**Pattern**: Parsing URLs with attacker-controlled input

**RustSec examples:**
- RUSTSEC-2021-0015: URL parsing issues

**Prevention:**
- Validate URL schemes
- Parse URLs safely
- Don't trust parsed components blindly

---

### 9. Timing Attacks

**Pattern**: Comparing sensitive values with early-return comparison

**RustSec examples:**
- RUSTSEC-2020-0017: Timing-safe comparison not used

**Prevention:**
- Use constant-time comparison for sensitive values
- Hash passwords before comparison
- Don't leak timing information

**Haskell equivalent:**
```haskell
-- GOOD: Constant-time comparison
import Crypto.MAC.HMAC (hmac)
import Data.ByteArray (consteq)

validate :: ByteString -> ByteString -> Bool
validate password hashed = consteq (hmac key password) hashed
```

---

### 10. Denial of Service via Resource Exhaustion

**Pattern**: Not limiting resource consumption

**RustSec examples:**
- RUSTSEC-2021-0019: Resource exhaustion

**Prevention:**
- Set limits on input sizes
- Use timeouts for operations
- Limit concurrent operations
- Rate limit API endpoints

---

## Ecosystem-Specific Considerations

### Haskell-Specific Patterns

While RustSec focuses on Rust, similar patterns exist in Haskell:

| Pattern | Haskell Consideration |
|---------|----------------------|
| **SQL Injection** | Use persistent/esqueleto with parameterized queries |
| **Command Injection** | Use `process` library safely, avoid `system` with user input |
| **Path Traversal** | Use `path` library, validate paths |
| **Deserialization** | Careful with `Read` instances, use safe parsers |
| **Crypto** | Use well-audited libraries (cryptonite, etc.) |

### Cross-Ecosystem Lessons

1. **Input validation** — Universal principle
2. **Parameterized queries** — Universal for databases
3. **Safe deserialization** — Universal for data formats
4. **Resource limits** — Universal for DoS prevention
5. **Constant-time operations** — Universal for crypto

---

## Monitoring Vulnerability Databases

### RustSec

- Website: https://rustsec.org/
- Format: YAML-based advisory database
- License: CC0-1.0

### Haskell

- Haskell Security Advisories: https://github.com/haskell/security-advisories
- Hackage audit: `cabal update && cabal check`

### General

- CVE database: https://cve.mitre.org/
- NVD: https://nvd.nist.gov/
- GitHub Security Advisories: https://github.com/advisories

---

## Applying These Patterns

### For Contributors

When writing code:

1. Check if your code matches any known vulnerability patterns
2. Use safe APIs and libraries
3. Validate all external input
4. Review dependencies for known vulnerabilities

### For Reviewers

When reviewing PRs:

1. Look for patterns from this list
2. Check for input validation
3. Verify safe library usage
4. Ask about edge cases

### For Maintainers

1. Monitor vulnerability databases for relevant advisories
2. Update dependencies promptly
3. Document security considerations
4. Train contributors on these patterns

---

## Resources

- [RustSec Advisory Database](https://rustsec.org/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE Top 25](https://cwe.mitre.org/top25/)
- [Haskell Security Advisories](https://github.com/haskell/security-advisories)

---

*Understanding vulnerability patterns across ecosystems helps us write more secure code in any language.*