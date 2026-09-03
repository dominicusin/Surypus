# Maintainer Guide

This guide is for current and future maintainers of the Surypus project. It covers the skills, responsibilities, and best practices for maintaining a successful open source project.

## Table of Contents

- [What is a Maintainer?](#what-is-a-maintainer)
- [Core Responsibilities](#core-responsibilities)
- [Leadership Skills](#leadership-skills)
- [Time Management](#time-management)
- [Community Management](#community-management)
- [Technical Oversight](#technical-oversight)
- [Burnout Prevention](#burnout-prevention)
- [Resources](#resources)

## What is a Maintainer?

A maintainer is someone who:

- **Guides the project direction** - Makes strategic decisions about features and priorities
- **Reviews contributions** - Ensures quality and consistency of code and documentation
- **Supports the community** - Helps users and contributors, answers questions
- **Manages releases** - Coordinates versioning, changelog, and deployment
- **Enforces standards** - Upholds the Code of Conduct and project guidelines

## Core Responsibilities

### 1. Code Review

- Review pull requests within **48 hours**
- Provide constructive, specific feedback
- Use conventional comments (nit, question, issue, praise, suggestion, blocker)
- Approve or request changes promptly

### 2. Issue Triage

- Respond to new issues within **48 hours**
- Label issues appropriately
- Close stale or duplicate issues
- Convert discussions to issues when appropriate

### 3. Community Support

- Answer questions in discussions and issues
- Welcome new contributors
- Recognize and thank contributions
- Foster a welcoming environment

### 4. Release Management

- Follow semantic versioning
- Update CHANGELOG.md
- Create GitHub releases
- Publish to Hackage (when applicable)

### 5. Documentation

- Keep README.md up to date
- Update CONTRIBUTING.md as needed
- Document architectural decisions (ADRs)
- Create tutorials and guides

## Leadership Skills

### Facilitate, Don't Dictate

- Seek consensus when possible
- Listen to all perspectives
- Explain the "why" behind decisions
- Be open to changing your mind

### Communicate Clearly

- Be concise and specific
- Use code comments and documentation
- Assume good intent
- Address issues, not people

### Set Boundaries

- Define your availability (e.g., "5 hours per week")
- Learn to say "no" gracefully
- Don't feel guilty about taking breaks
- Prioritize your well-being

## Time Management

### Prioritize Ruthlessly

Focus on activities that have the most impact:

1. **Critical** - Security issues, data loss bugs
2. **High** - Breaking bugs, popular feature requests
3. **Medium** - Improvements, documentation
4. **Low** - Nice-to-have features, edge cases

### Batch Tasks

- Review PRs in batches (e.g., once per day)
- Process issues in dedicated time blocks
- Use templates and automation to save time

### Automate Everything

- Use GitHub Actions for CI/CD
- Auto-respond to new issues/PRs
- Auto-close stale issues
- Auto-merge Dependabot PRs

## Community Management

### Welcome New Contributors

- Thank them for their first contribution
- Provide clear, actionable feedback
- Point them to good first issues
- Recognize their work publicly

### Handle Conflict

- Stay neutral and professional
- Focus on the issue, not the person
- Use the Code of Conduct as a guide
- De-escalate when necessary

### Say "No" Gracefully

When declining a contribution:

1. **Thank** the contributor for their work
2. **Explain** why it doesn't fit
3. **Suggest** alternatives if possible
4. **Close** the PR/issue promptly

Example:
> Thank you for this contribution! While the idea is interesting, it doesn't align with our current project scope. We're focusing on core ERP functionality. Feel free to fork the project if you'd like to pursue this direction.

## Technical Oversight

### Code Quality

- Enforce coding standards
- Require tests for new functionality
- Use linters and formatters
- Review for security vulnerabilities

### Architecture Decisions

- Document significant decisions (ADRs)
- Discuss major changes in issues first
- Consider long-term maintainability
- Avoid premature optimization

### Security

- Respond to security issues immediately
- Use Dependabot for dependency updates
- Enable secret scanning
- Follow responsible disclosure

## Burnout Prevention

### Recognize the Signs

- Dreading project notifications
- Feeling guilty about unresponded issues
- Avoiding the project
- Irritability with community members

### Preventive Measures

- **Set boundaries** - Define your availability
- **Take breaks** - Step away when needed
- **Share responsibility** - Recruit other maintainers
- **Automate** - Reduce repetitive tasks
- **Say no** - Don't overcommit

### When You Need a Break

1. **Announce** your absence to the community
2. **Document** what needs attention
3. **Empower** other maintainers to help
4. **Disconnect** fully during your break
5. **Return** when you're ready

## Resources

### Internal

- [Code of Conduct](../CODE_OF_CONDUCT.md)
- [Contributing Guidelines](../CONTRIBUTING.md)
- [Code Review Guidelines](../CODE_REVIEW_GUIDELINES.md)
- [Governance](../GOVERNANCE.md)
- [Vision](../VISION.md)

### External

- [Open Source Guide](https://opensource.guide/)
- [Maintainer Community](https://maintainers.github.com/)
- [GitHub Docs](https://docs.github.com/)

---

*Last updated: 2026-09-03*
