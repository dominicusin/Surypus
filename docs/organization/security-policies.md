# Surypus Organization Security Policies

## Branch Protection Rules

### Main Branch Protection

```bash
# Apply to all repositories in surypus organization
gh api -X PUT repos/{org}/{repo}/branches/main/protection \
  -F required_status_checks='{"strict": true, "contexts": ["CI", "Coverage Gate", "Pre-commit Hooks"]}' \
  -F enforce_admins=false \
  -F required_pull_request_reviews='{"required_approving_review_count": 1, "dismiss_stale_reviews": true, "require_code_owner_review": true}' \
  -F restrictions=null \
  -F required_linear_history=true \
  -F allow_force_pushes=false \
  -F allow_deletions=false
```

### Required Status Checks

- CI
- Coverage Gate
- Pre-commit Hooks
- Secret Guard

## Security Features

### Enable for all repositories

```bash
# Enable secret scanning
gh api -X PATCH repos/{org}/{repo} \
  -F security_and_analysis='{"secret_scanning": {"status": "enabled"}, "secret_scanning_push_protection": {"status": "enabled"}}'

# Enable Dependabot alerts
gh api -X PUT repos/{org}/{repo}/vulnerability-alerts

# Enable Dependabot security fixes
gh api -X PUT repos/{org}/{repo}/automated-security-fixes
```

## Repository Rulesets

### Prevent force push to main

```bash
gh api -X POST orgs/{org}/rulesets \
  -F name="Prevent force push" \
  -F target="branch" \
  -F enforcement="active" \
  -F conditions='{"ref_name": {"include": ["refs/heads/main"], "exclude": []}}' \
  -F rules='[{"type": "non_fast_forward"}]'
```

### Require PR before merging to main

```bash
gh api -X POST orgs/{org}/rulesets \
  -F name="Require PR" \
  -F target="branch" \
  -F enforcement="active" \
  -F conditions='{"ref_name": {"include": ["refs/heads/main"], "exclude": []}}' \
  -F rules='[{"type": "pull_request", "parameters": {"required_approving_review_count": 1, "dismiss_stale_reviews_on_push": true, "require_code_owner_review": true, "require_last_push_approval": false, "required_review_thread_resolution": false}}]'
```

## CODEOWNERS Template

```
# CODEOWNERS for Surypus projects
# https://docs.github.com/en/repositories/managing-your-repositorys-settings/customizing-code-ownership/about-code-owners

# Global owners
* @dominicusin

# CI/CD changes require admin approval
.github/ @dominicusin

# Documentation
docs/ @dominicusin
*.md @dominicusin

# Database migrations
sql/migrations/ @dominicusin

# Core library code
src/ @dominicusin

# Tests
test/ @dominicusin
```

## Security Policy Template

```markdown
# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| main    | ✅        |
| < 1.0   | ❌        |

## Reporting a Vulnerability

Report privately to the maintainer via GitHub Security Advisories (Draft a security advisory under **Security → Advisories** in this repo). Do NOT open a public issue.

We enable Dependabot alerts + security updates; fixes are merged to `main` and released as a patch.
```
