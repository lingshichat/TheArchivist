# Backend Development Guidelines

> Best practices for backend development in this project.

---

## Overview

In this repository, "backend" means the non-presentation execution layers:

- Flutter runtime data / repository / integration code under `lib/`
- Trellis automation scripts when they affect delivery flow or operator output

This is **not** a server-only directory.

Use these docs for repository writes, sync/integration services, script output,
and other non-UI code paths.

---

## Pre-Development Checklist

- [ ] If the change touches 3+ layers or a durable contract, read
      `../architecture/index.md` first
- [ ] Read [Directory Structure](./directory-structure.md) before placing new
      non-UI files
- [ ] Read [Database Guidelines](./database-guidelines.md) before changing
      Drift tables, DAOs, repositories, or sync-capable fields
- [ ] Read [Error Handling](./error-handling.md) before adding network, sync,
      or storage error paths
- [ ] Read [Logging Guidelines](./logging-guidelines.md) before changing CLI
      output, sync diagnostics, or activity-log behavior
- [ ] Read [Quality Guidelines](./quality-guidelines.md) before changing
      controllers, repositories, or integration services

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Error Handling](./error-handling.md) | Sealed exceptions, error layering, local-first error policy | Active |
| [Directory Structure](./directory-structure.md) | Placement and ownership rules for repositories, services, providers, and scripts | Active |
| [Database Guidelines](./database-guidelines.md) | Drift patterns, sync-capable fields, repository ownership | Active |
| [Quality Guidelines](./quality-guidelines.md) | Quality bar for controllers, repositories, services, and automation code | Active |
| [Logging Guidelines](./logging-guidelines.md) | CLI output, app-side diagnostics, and activity-log boundaries | Active |

---

**Language**: All documentation should be written in **English**.
