# Phase 16: Notifications - Context

**Gathered:** 2026-05-19
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

Implement email and desktop push notification system.

**Requirements:** NOTIF-01, NOTIF-02, NOTIF-03, NOTIF-04

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices at Claude's discretion. Use ROADMAP success criteria:
- Email notifications sent for configurable events
- Desktop push notifications work (Qt system tray)
- User can set notification preferences
- Digest mode sends daily/weekly summaries

</decisions>

<code_context>
## Existing Code Insights

- WebSocket notifications exist in `src/Surypus/WebSocket.hs`
- Email capability: Not yet implemented. Need SMTP library or external service.
- QML desktop app has system tray capabilities (Qt)
- Notification preferences table likely needed in DB

</code_context>

<specifics>
## Success Criteria
1. Email notifications sent for configurable events
2. Desktop push notifications work (Qt system tray)
3. User can set notification preferences
4. Digest mode sends daily/weekly summaries

</specifics>

<deferred>
None.
</deferred>
