# Database Guidelines

> Drift conventions for this project.

---

## Overview

This project uses [Drift](https://drift.simonbinder.eu/) (v2.x) as the local
persistence layer, backed by SQLite via `drift_flutter` and
`sqlite3_flutter_libs`.

The database lives at the platform default directory and the local database is
named `record_anywhere`.

---

## Naming Conventions

- **Tables**: PascalCase class names extending `Table`
- **Columns**: camelCase getters in Dart, `snake_case` in SQL
- **Primary keys**: `id TEXT` with UUID v4 generated in app code
- **Foreign keys**: explicit `references(...)`
- **Join tables**: use `media_item_tags` / `media_item_shelves` style naming

---

## Enum Storage

Enums are stored as text with `TypeConverter`, not integer indexes.

Current enum sets:

- `MediaType`: `movie` / `tv` / `book` / `game`
- `UnifiedStatus`: `wishlist` / `inProgress` / `done` / `onHold` / `dropped`
- `ActivityEvent`: `added` / `statusChanged` / `scoreChanged` /
  `progressChanged` / `noteEdited` / `completed`
- `ShelfKind`: `system` / `user`

Text storage is required because later sync work must survive enum reordering.

---

## Sync Fields

Business tables that may sync later carry:

- `createdAt`
- `updatedAt`
- `deletedAt`
- `syncVersion`
- `deviceId`
- `lastSyncedAt`

Repository methods own these fields. UI code must not stamp them.

---

## Soft Delete

- Normal product flows use soft delete
- Read queries must filter out `deletedAt IS NOT NULL`
- Hard delete is reserved for future backup/restore or maintenance flows

---

## Directory Structure

```text
lib/shared/data/
├── app_database.dart
├── providers.dart
├── converters/
├── tables/
├── daos/
└── repositories/
```

Layering:

UI -> Riverpod providers -> repositories -> DAOs -> Drift tables

---

## Query Patterns

- **Home**:
  - `watchContinuing`
  - `watchRecentlyAdded`
  - `watchRecentlyFinished`
  - all join `media_items + user_entries + progress_entries`
- **Library**:
  - `watchLibrary`
  - filter by media type list + status
  - sort by `updatedAt`, `title`, `score`, or `releaseDate`
- **Detail**:
  - `watchDetailBase` joins `media_items + user_entries + progress_entries`
  - tags / shelves / activity logs are combined above the DAO layer
- **Joins**:
  - use `select().join([...])`
  - map with `row.readTable()` / `row.readTableOrNull()`

---

## Raw Drift SQL

- `Variable<T>` uses a non-nullable type argument even when the value may be
  null. For nullable text bindings, use `Variable<String>(maybeNullValue)`,
  not `Variable<String?>(maybeNullValue)`.
- Keep the SQL placeholder count and `variables` list count aligned in the same
  edit. Nullable columns still need an explicit variable slot when the value is
  null.

---

## WP4 Local Record Contracts

- `watchLibrary` accepts `types` so one tab can represent multiple media types
  (`movie + tv`)
- Year sorting in the desktop library maps to `releaseDate`
- `activity_logs` is append-only and backs the visible lifecycle timeline
- Do not reconstruct lifecycle UI from `updatedAt` fields alone
- `user_entries.updateStatus` semantics:
  - first move to `inProgress` writes `startedAt` if missing
  - move to `done` writes `finishedAt`
  - move away from `done` clears `finishedAt`
- Tag and shelf syncing should happen at repository level so page code can work
  with plain text names

---

## Migrations

- `schemaVersion` starts at 1
- Bump the version for every schema change
- Keep upgrades incremental with `if (from < N)` blocks
- Test migrations with in-memory databases

---

## Generated Code

- Run `dart run build_runner build --delete-conflicting-outputs` after Drift
  schema or DAO changes
- Keep generated `*.g.dart` files in sync with source before analyze/test

---

## Testing

Use `AppDatabase.forTesting(NativeDatabase.memory())` in repository tests.

Notes:

- SQLite timestamp precision is second-level in current tests
- Add round-trip tests for create -> mutate -> soft delete flows when contracts
  span multiple repositories

---

## Common Mistakes

- Using integer-backed enums for sync-facing data
- Letting page widgets call DAOs directly
- Forgetting to filter soft-deleted rows
- Reconstructing lifecycle history without `activity_logs`
- Copying name-sync logic for tags and shelves into page widgets
