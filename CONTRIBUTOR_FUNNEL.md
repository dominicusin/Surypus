# Contributor Funnel

This document describes the journey from first-time user to active maintainer, inspired by @MikeMcQuaid's contributor funnel concept.

## The Contributor Funnel

```
┌─────────────────────────────────────────────────────────────┐
│                    POTENTIAL USER                           │
│                  (discovers project)                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      USER                                   │
│              (uses the project)                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   CONTRIBUTOR                               │
│            (makes first contribution)                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                REGULAR CONTRIBUTOR                          │
│           (contributes regularly)                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    MAINTAINER                               │
│           (maintains the project)                           │
└─────────────────────────────────────────────────────────────┘
```

## Stage 1: Potential User → User

**Goal**: Make it easy for people to discover and start using Surypus.

### How People Find Us

- GitHub search (topics: haskell, erp, formal-verification)
- Hackage package listings
- Blog posts and tutorials
- Conference talks
- Word of mouth

### Reducing Friction

- ✅ Clear README with badges and quick start
- ✅ Comprehensive documentation
- ✅ Working examples
- ✅ Docker support for easy setup
- ✅ devcontainer for GitHub Codespaces

### Metrics to Track

- GitHub stars
- Package downloads (Hackage)
- Docker pulls
- Website traffic

## Stage 2: User → Contributor

**Goal**: Convert users into contributors.

### Entry Points

1. **Good First Issues** - Labeled issues that are easy for beginners
2. **Documentation fixes** - Typos, clarifications, translations
3. **Bug reports** - Reporting issues is a form of contribution
4. **Feature requests** - Suggesting improvements

### Reducing Friction

- ✅ Clear CONTRIBUTING.md
- ✅ Issue templates (bug report, feature request)
- ✅ PR template with checklist
- ✅ Code review guidelines
- ✅ Auto-response SLA workflow

### First Contribution Experience

When someone makes their first contribution:

1. **Thank them** - Auto-response acknowledges their contribution
2. **Quick review** - Review within 48 hours
3. **Be kind** - Provide constructive feedback
4. **Celebrate** - Merge and thank them publicly

## Stage 3: Contributor → Regular Contributor

**Goal**: Keep contributors engaged and coming back.

### Strategies

1. **Recognition** - Thank contributors in release notes
2. **Ownership** - Let contributors own features/modules
3. **Mentorship** - Help them grow as developers
4. **Community** - Make them feel part of the team

### Reducing Friction

- ✅ Clear labeling system
- ✅ Good first issues always available
- ✅ Responsive maintainers
- ✅ Transparent decision-making

### Metrics to Track

- Number of contributors
- Contributions per contributor
- Time between contributions
- Contributor retention rate

## Stage 4: Regular Contributor → Maintainer

**Goal**: Identify and empower future maintainers.

### Identifying Potential Maintainers

- Consistently contributes quality code
- Helps other contributors
- Understands the project vision
- Has good communication skills

### Empowering Maintainers

1. **Increase responsibility** - Let them review PRs, triage issues
2. **Share ownership** - Give them commit access
3. **Mentor others** - Let them onboard new contributors
4. **Decision making** - Include them in strategic decisions

### Reducing Friction

- ✅ Clear governance (GOVERNANCE.md)
- ✅ Shared ownership model
- ✅ Transparent promotion process
- ✅ Recognition of contributions

## Community Health Metrics

### Discoverability

| Metric | Current | Target |
|--------|---------|--------|
| GitHub stars | 📊 | 1000+ |
| Package downloads | 📊 | 10000+ |
| Website traffic | 📊 | 1000/month |

### Usage

| Metric | Current | Target |
|--------|---------|--------|
| Active users | 📊 | 100+ |
| Docker pulls | 📊 | 10000+ |
| Forks | 📊 | 100+ |

### Retention

| Metric | Current | Target |
|--------|---------|--------|
| Total contributors | 📊 | 100+ |
| Regular contributors | 📊 | 20+ |
| Maintainers | 1 | 3+ |

### Maintainer Activity

| Metric | Target |
|--------|--------|
| Issue response time | < 48 hours |
| PR review time | < 48 hours |
| Release cadence | Monthly |

## Reducing Friction at Every Stage

### Documentation

- ✅ README.md - Clear and comprehensive
- ✅ CONTRIBUTING.md - Detailed contribution guide
- ✅ CODE_OF_CONDUCT.md - Community standards
- ✅ SECURITY.md - Security policy
- ✅ GOVERNANCE.md - Project governance
- ✅ COMMUNITY.md - Community guide
- ✅ SUPPORT.md - Support resources

### Automation

- ✅ Auto-response SLA - Acknowledges new issues/PRs
- ✅ Stale management - Handles inactive issues/PRs
- ✅ Project metrics - Weekly metrics reports
- ✅ Community engagement - Engagement reports

### Communication

- ✅ GitHub Discussions - Open forum
- ✅ Issue templates - Structured reports
- ✅ PR template - Clear expectations
- ✅ Code review guidelines - Consistent feedback

## Acting on Feedback

This document is a living document. We regularly review and update our contributor funnel based on community feedback.

### How to Provide Feedback

- Open a [GitHub Discussion](https://github.com/surypus/surypus/discussions)
- Comment on this document via PR
- Reach out to maintainers directly

---

*Last updated: 2026-09-03*
