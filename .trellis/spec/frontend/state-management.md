# State Management

> How state is managed in this project.

---

## Overview

This project uses `flutter_riverpod` as the application-level state solution.

Current Phase 1 scope is intentionally light:

- App bootstrap uses a root `ProviderScope`
- Router configuration is exposed via a Riverpod provider
- Page skeletons currently render demo data and local UI state only

This keeps WP1 focused on shell and theme work while leaving room for WP2/WP4
to introduce data providers and mutation flows later.

---

## State Categories

- **Application state**
  - Router and future app-wide preferences
  - Lives in Riverpod providers
- **Feature-local UI state**
  - Temporary segmented controls, filters, and placeholders
  - Can remain local until multiple widgets need to share it
- **Domain/data state**
  - Local database, sync state, and Bangumi integration
  - Not part of the initial WP1 shell implementation

---

## When to Use Global State

Promote state to Riverpod when:

- It is shared by multiple routes or shell-level widgets
- It survives page rebuilds and must stay coherent
- It represents app-level preference or data lifecycle

Keep state local when:

- It only affects a single widget subtree
- It is temporary visual interaction state
- It does not yet cross feature boundaries

---

## Server State

There is no remote/server-state layer in WP1.

Planned later:

- Local-first persistence will come from Drift-backed repositories
- Sync state and remote integrations should enter through explicit providers
- UI must not talk directly to transport or storage details

---

## Common Mistakes

- Creating global providers for one-off widget presentation state
- Letting page widgets depend on storage or transport details too early
- Duplicating route-selection logic in both shell and feature layers
