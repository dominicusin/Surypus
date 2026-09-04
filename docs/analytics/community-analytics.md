# Community Analytics & Metrics

This document defines the community analytics strategy for Surypus.

## Why Analytics Matter

- Track contributor funnel health
- Spot onboarding friction early
- Measure maintainer responsiveness
- Correlate docs/templates changes with contributor retention

## Metrics

### Funnel Metrics

| Metric | How to Measure | Target |
|--------|----------------|--------|
| Visitors to repo | GitHub traffic | +10% MoM |
| Visitors → issue/report | Issues opened | +15% MoM |
| Report → PR opened | PRs opened | +20% MoM |
| PR opened → merged | Merged PRs | >70% merge rate |
| New contributors | First merged PR | 2+ per month |

### Response Metrics

| Metric | How to Measure | Target |
|--------|----------------|--------|
| Time to first issue response | Comments on new issues | <48 hours |
| Time to first PR review | PR reviews | <72 hours |
| Maintainer coverage | Active maintainers/week | 1+ |

### Retention Metrics

| Metric | How to Measure | Target |
|--------|----------------|--------|
| Returning contributors | Repeat PR authors | +25% QoQ |
| Stale issue/PR age | Workflow report | <14 days old |
| Contributor churn | 90-day inactive rate | <20% |

### Engagement Metrics

- Discussion participation rate
- `good first issue` resolution time
- New contributors added per release
- Sponsorship/funding growth

## Data Sources

- GitHub API: traffic, issues, PRs, discussions, contributors
- Existing workflows:
  - `community-health.yml`
  - `community-engagement.yml`
  - `project-metrics.yml`
  - `usage-metrics.yml`

## Reporting

- Weekly: engagement snapshot
- Monthly: health report issue
- Quarterly: contributor retention review

## Action Loop

1. Collect metrics
2. Publish summary
3. Identify friction points
4. Update docs/templates
5. Re-measure after 30 days
