# State Management

> How state is managed in this project.

---

## Overview

This project uses `flutter_riverpod` as the application-level state solution.

Phase 1 now has a real local-first loop:

- App bootstrap still uses a root `ProviderScope`
- Router configuration is still exposed via a provider
- Home / Library / Detail now read from Drift-backed `StreamProvider`s
- Add / Detail write flows now go through feature controllers
- Page-local filters, dialog state, and text editing state stay local

The goal is to keep page widgets presentation-first while the data semantics
live in repositories and controllers.

---

## State Categories

- **Application state**
  - Router and future app-wide preferences
  - Lives in Riverpod providers
- **Feature-local UI state**
  - Selected tabs, filters, form text, dialog visibility
  - Stays local unless multiple routes need to share it
- **Domain/data state**
  - Local database, sync state, Bangumi integration
  - Read through repository-backed Riverpod providers
  - Written through feature-scoped controllers

---

## When to Use Global State

Promote state to Riverpod when:

- It is shared by multiple routes or shell-level widgets
- It survives page rebuilds and must stay coherent
- It represents app-level preference or data lifecycle
- It is a live read model backed by Drift streams

Keep state local when:

- It only affects a single widget subtree
- It is temporary visual interaction state
- It is form editing state that can be submitted in one action

---

## Local-First Read Pattern

Use `StreamProvider` / `StreamProvider.family` for live archive reads.

Rules:

- Providers read from repositories, not directly from page widgets
- Feature providers adapt DB entities into feature view data
- Shared widgets should still consume stable UI models such as
  `PosterViewData` and `CategoryViewData`
- Missing records should resolve to `null` or empty view data, not demo
  fallbacks

Current examples:

- `homeViewDataProvider`
- `libraryHeaderProvider`
- `libraryItemsProvider`
- `detailViewDataProvider`

---

## Local-First Write Pattern

Use controller classes for multi-step writes.

Rules:

- Pages trigger controller methods
- Controllers orchestrate repository writes
- Activity-log appends belong next to the mutation path
- Pages should only handle progress UI, dialogs, and success feedback

Current examples:

- `AddEntryController`
- `DetailActionsController`

---

## Server State

There is no remote/server-state layer in Phase 1.

Current local-first pattern:

- Local persistence comes from Drift-backed repositories
- Sync state and remote integrations will enter through explicit providers later
- UI must not talk directly to transport or storage details

---

## Common Mistakes

- Creating global providers for one-off widget presentation state
- Letting page widgets call DAO methods directly
- Doing multi-step writes inside button callbacks
- Returning Drift row objects straight into shared presentation widgets
- Duplicating route-selection logic in both shell and feature layers
