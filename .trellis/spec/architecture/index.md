# Architecture Guidelines

> Cross-layer contracts and system boundaries for this project.

---

## Overview

This directory stores long-lived architectural rules that span multiple
features, phases, or implementation layers.

Read these documents before changing any of the following:

- shared provider placement
- local-first write and sync flows
- external integration boundaries
- parent/child task ownership for durable decisions

These docs complement `backend/`, `frontend/`, and `guides/`. They are the
place for rules that should outlive a single work package.

---

## Pre-Development Checklist

- [ ] If the change touches 3+ layers, read
      [System Boundaries](./system-boundaries.md)
- [ ] If the change affects local writes, sync fields, conflict policy, or
      remote push/pull, read
      [Local-First Sync Contract](./local-first-sync-contract.md)
- [ ] If the change reshapes parent/child task ownership or moves durable
      decisions across tasks, read
      [Task & Spec Governance](./task-spec-governance.md)
- [ ] After reading architecture docs, continue with the relevant
      `backend/` and `frontend/` specs for the concrete implementation rules

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [System Boundaries](./system-boundaries.md) | Layer ownership, dependency direction, provider placement | Active |
| [Local-First Sync Contract](./local-first-sync-contract.md) | Source-of-truth rules, sync fields, remote side-effect boundaries | Active |
| [Task & Spec Governance](./task-spec-governance.md) | Durable-decision placement across parent tasks, child tasks, and specs | Active |

---

**Language**: All documentation in this directory should be written in
**English**.
