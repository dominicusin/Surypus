# Maintainer Sustainability Guide

Practical strategies for sustainable open source maintainership.

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
---Thank you to all the maintainers who shared their wisdom for this guide!
<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

---

## The Sustainability Challenge

Open source maintainership is often seen as a labor of love, but sustaining it long-term requires more than enthusiasm. It requires:

- Realistic expectations about time and energy
- Systems that reduce repetitive work
- Community support structures
- Clear boundaries and communication
- Financial sustainability (when possible)

This guide covers practical strategies for each area.

---

## Realistic Expectations

### Time

**How much time do you actually have?**

Be honest with yourself. Consider:

- Your day job and other commitments
- Family and personal time
- Health and energy levels
- Other open source projects

**Exercise:** Track your time for one week. How much did you spend on Surypus? Was it sustainable?

**Common patterns:**
- Many maintainers spend 5-10 hours/week on their projects
- Some work in bursts (sprint then rest)
- Some have regular weekly time blocks

There's no "right" amount. Find what works for you.

### Energy

**What drains you? What energizes you?**

| Draining Activities | Energizing Activities |
|---------------------|----------------------|
| Reviewing large PRs | Helping new contributors |
| Dealing with conflicts | Writing documentation |
| Responding to unfair criticism | Learning new things |
| Context switching | Deep work on features |

**Strategy:** Structure your work to maximize energizing activities and minimize draining ones.

---

## Automation Strategies

Automate repetitive tasks to free up time for meaningful work.

### What to Automate

| Task | Tool/Approach |
|------|---------------|
| Welcome new contributors | `welcome-contributors.yml` |
| Stale issue management | `stale.yml` |
| Label issues/PRs | `labeler.yml` |
| Auto-merge dependencies | `auto-merge-deps.yml` |
| CI/CD runs | GitHub Actions workflows |
| Release notes | `release-drafter.yml` |
| Security scanning | CodeQL, Secret scanning |

### What NOT to Automate

- Code review (personal judgment needed)
- Community interactions (authenticity matters)
- Strategic decisions (human judgment essential)
- Conflict resolution (empathy required)

### GitHub Actions for Maintainer Support

Consider these additional automations:

- **Reminder bots** - Gently remind about stale PRs
- **Assignment bots** - Auto-assign issues to willing contributors
- **Thank-you bots** - Celebrate milestones
- **Status updates** - Auto-post about your availability

---

## Support Structures

### Delegate to Contributors

Your contributors are your best resource. Use them.

**Delegation opportunities:**
- Triaging issues (labeling, closing duplicates)
- Reviewing straightforward PRs
- Writing documentation
- Answering questions in discussions
- Organizing community events
- Creating tutorials and examples

**How to delegate effectively:**
1. Identify tasks you can hand off
2. Find contributors interested in those tasks
3. Give clear expectations and guidelines
4. Trust them to do the work
5. Provide feedback and recognition

### Build a Team

You don't have to maintain a project alone.

**Team structures:**
- **Co-maintainers** - Shared ownership, similar responsibilities
- **Maintainers for areas** - Different people own different modules
- **Advisory board** - Guidance without direct maintenance work
- **Community managers** - Handle community interactions

**How to recruit team members:**
- Look for consistent, helpful contributors
- Ask them directly if they'd be interested
- Offer clear roles and expectations
- Start with small responsibilities and grow

### Seek External Support

**Resources:**
- [Maintainer Community](https://maintainers.github.io/) - Connect with other maintainers
- [SustainOSS](https://www.sustainoss.org/) - Funding and sustainability resources
- [Open Source Collective](https://www.opencollective.com/) - Fiscal sponsorship
- [GitHub Sponsors](https://github.com/sponsors) - Direct funding

**Types of support:**
- Emotional support (talking with other maintainers)
- Technical support (collaborators who help with work)
- Financial support (sponsors, grants, paid contracts)
- Legal support (advice on licensing, trademarks)

---

## Communication Strategies

### Responsive But Not Instant

You don't need to respond immediately to everything.

**Reasonable response times:**
- Bug reports: 48 hours
- Feature requests: 1 week
- PRs: 48 hours
- General questions: 1 week

If you can't meet these times, that's okay. Set expectations clearly and communicate delays.

### Deflecting Private Messages

Private messages lead to burnout. Public channels are better for the community.

**Politely redirect:**
> "Hey! Could you please ask this in a GitHub issue? It'll help others who have the same question, and I'll be able to respond more thoughtfully."

### Setting Response Expectations

**In your README or CONTRIBUTING:**
> "I try to respond to issues within 48 hours on weekdays. I don't work weekends. For urgent matters, please cc [backup maintainer]."

**During breaks:**
> "I'm on vacation until [date]. I won't be responding to issues or PRs during this time."

### Handling Unreasonable Expectations

Some people will make demands that aren't reasonable. That's okay. You can politely decline.

> "I understand this is important to you, but I'm not able to [request]. This is outside the scope of my involvement with the project. If you'd like to work on this yourself, I'm happy to review your contribution."

---

## Financial Sustainability

### Funding Options

| Option | Description | Best For |
|--------|-------------|----------|
| GitHub Sponsors | Monthly recurring donations | Individual maintainers |
| Open Collective | Fiscal sponsorship + donations | Communities, projects |
| Grants | One-time funding for specific work | Specific initiatives |
| Consulting | Paid work related to the project | Individual maintainers |
| Commercial support | Paid support contracts | Projects with enterprise users |

### Choosing a Funding Model

**Consider:**
- Your goals (covering costs vs. full-time work)
- Your community's expectations
- Legal and tax implications
- Transparency and accountability

### Asking for Support

**Be specific about what funding enables:**
- "Your sponsorship helps me spend 10 hours/week on this project."
- "Funding supports documentation improvements."
- "Sponsors get priority support and early access to features."

**Be transparent:**
- Share how funds are used
- Report on progress and impact
- Thank sponsors publicly (with permission)

---

## Taking Breaks

### Why Breaks Matter

Breaks prevent burnout and improve the quality of your work. They're not a luxury—they're essential.

### Types of Breaks

| Type | Duration | When |
|------|----------|------|
| Daily breaks | 15-30 min | Throughout the day |
| Weekly breaks | 1-2 days | Weekends typically |
| Monthly breaks | 3-7 days | Once per month/quarter |
| Sabbatical | 1-4 weeks | Once per year or when needed |

### Taking a Break Well

1. **Plan ahead** - Give advance notice when possible
2. **Set expectations** - Update your status and auto-responder
3. **Delegate** - Have someone cover urgent matters
4. **Disconnect** - Actually step away
5. **Return gradually** - Start with small tasks

### Coming Back from a Break

If coming back feels hard:
1. Start with low-energy tasks (documentation, triage)
2. Delegate more until you're back to full capacity
3. Reconnect with your motivation
4. Consider if you need longer-term changes

---

## Re-evaluating Your Involvement

### Signs You May Need to Change Something

- You dread working on the project
- You're constantly tired or stressed
- You're neglecting other important areas of life
- You feel resentful toward users or contributors
- You can't imagine continuing for another year

### Options for Adjusting

- **Reduce scope:** Focus on fewer things
- **Delegate more:** Hand off more responsibilities
- **Take a break:** Step back temporarily
- **Step down:** Find a new maintainer or archive the project

### Stepping Down Gracefully

If you decide to step down:

1. **Find a successor** - Ask trusted contributors
2. **Document everything** - Key decisions, processes, contacts
3. **Transfer access** - Give repository and other access
4. **Announce clearly** - Thank contributors, explain the transition
5. **Stay available for questions** - During the transition period

---

## Resources

- [Maintainer Community](https://maintainers.github.io/)
- [SustainOSS](https://www.sustainoss.org/)
- [The Maintainer's Corner](https://www.themaintainers.com/)
- [Open Source Guide: Funding](https://opensource.guide/funding/)
- [Burnout Checklist (Shawn Aguire)](https://shaunagm.github.io/)
- [Saying No, Mike McQuaid](https://github.com/MikeMcQuaid/opensource.guide/blob/main/community/maintainers/saying-no.md)
- [Rockwood Leadership Institute](https://rockwoodleadership.org/)

---

## Maintenance Checklist

Use this checklist to assess your sustainability each quarter:

- [ ] Am I spending a sustainable amount of time on this project?
- [ ] Am I energized or drained after working on it?
- [ ] Do I have boundaries that I'm maintaining?
- [ ] Do I have support from other maintainers or contributors?
- [ ] Am I taking regular breaks?
- [ ] Have I delegated tasks that others can handle?
- [ ] Am I communicating clearly about my availability?
- [ ] Am I recognizing and celebrating contributions?
- [ ] Are my funding mechanisms working (if applicable)?
- [ ] Do I have activities outside of open source that I enjoy?

If you checked "no" on several of these, consider what changes you can make.

---

*Sustainability is a practice, not a destination. Keep adjusting as you learn what works for you.*