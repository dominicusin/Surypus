---
phase: "23"
name: "Mobile Apps"
created: 2026-05-21
status: ready
---

# Phase 23: Mobile Apps — Context

**Gathered:** 2026-05-21
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

## Phase Boundary

Native mobile applications for iOS and Android.

### Requirements
- MOB-01: React Native or Flutter mobile app
- MOB-02: Offline-first data sync
- MOB-03: Push notifications

### Success Criteria
- React Native or Flutter mobile app
- Offline-first data sync
- Push notifications
- Biometric authentication

## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — discuss phase was skipped per user setting. Using ROADMAP phase goal and success criteria to guide decisions.

- **Framework**: React Native (better ecosystem, shared code with web)
- **State Management**: Redux Toolkit
- **Offline**: WatermelonDB or MMKV for offline-first
- **Notifications**: Firebase Cloud Messaging
- **Auth**: Expo Auth Session + biometric local auth

## Codebase Context

The Surypus backend API is available with JWT authentication. The existing Haskell backend provides:
- RESTful API endpoints
- JWT-based authentication
- WebSocket support for real-time updates

## Specific Ideas

1. **Shared Types**: Generate TypeScript types from Haskell API types
2. **Navigation**: React Navigation v6 with auth flow
3. **UI Components**: React Native Paper or custom design system
4. **Data Layer**: React Query + WatermelonDB for sync
