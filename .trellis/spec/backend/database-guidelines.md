# Database Guidelines

> Drift conventions for this project.

---

## Overview

This project uses [Drift](https://drift.simonbinder.eu/) (v2.x) as the local persistence layer, backed by SQLite via `drift_flutter` and `sqlite3_flutter_libs`.

The database lives at the platform's default database directory and is named `record_anywhere.db`.

---

## Naming Conventions

- **Tables**: PascalCase class names extending `Table`. Drift generates the SQL table name as `snake_case`.
  - Example: `MediaItems` class → `media_items` table
- **Columns**: camelCase getters in the table class. Drift generates `snake_case` SQL columns.
  - Example: `mediaType` getter → `media_type` column
- **Primary keys**: All business tables use `id TEXT` (UUID v4), set explicitly via `primaryKey` override.
- **Foreign keys**: `text().references(OtherTable, #column)()` — Drift generates FK constraints.
- **Join tables**: Follow `media_item_tags` / `media_item_shelves` pattern: both FK columns + unique constraint.

---

## Enum Storage

Enums are stored as **text strings** using `TypeConverter` with `.map()`.

```dart
// converter
class StatusConverter extends TypeConverter<UnifiedStatus, String> { ... }

// table column
TextColumn get status => text().map(const StatusConverter())();
```

**Why text, not int index**: Text survives enum reordering and is readable in raw SQL. Critical for cross-device sync where enum index collisions would corrupt data.

Enums:
- `MediaType`: `movie` / `tv` / `book` / `game`
- `UnifiedStatus`: `wishlist` / `inProgress` / `done` / `onHold` / `dropped`
- `ActivityEvent`: `added` / `statusChanged` / `scoreChanged` / `progressChanged` / `noteEdited` / `completed`
- `ShelfKind`: `system` / `user`

---

## Sync Fields (All Business Tables)

Every table that may participate in cross-device sync carries these columns:

| Column | Type | Default | Purpose |
|--------|------|---------|---------|
| `createdAt` | DateTime | required | Row creation time |
| `updatedAt` | DateTime | required | Last modification time |
| `deletedAt` | DateTime? | null | Soft delete marker |
| `syncVersion` | INTEGER | 0 | Incremented on every write |
| `deviceId` | TEXT | '' | Device that made the change |
| `lastSyncedAt` | DateTime? | null | Last successful sync timestamp |

These fields are **auto-injected** by repository methods, not by UI code.

---

## Soft Delete

All business queries filter out `deletedAt IS NOT NULL` by default.

Hard delete is reserved for backup/restore paths (Phase 4). Never call `delete()` on business tables in normal flows — use `softDelete()` from the DAO/repository.

---

## ID Strategy

All primary keys are UUID v4 strings (36 chars), generated via the `uuid` package.

Rationale:
- Globally unique across devices — no collision during Phase 3 sync merge
- No need to rewrite FK references when merging data
- Slight index overhead acceptable at project scale

---

## Directory Structure

```
lib/shared/data/
├── app_database.dart       # @DriftDatabase class
├── providers.dart           # Riverpod providers
├── converters/              # TypeConverter classes
├── tables/                  # Table definitions + enums
├── daos/                    # @DriftAccessor DAOs
└── repositories/            # High-level write/read API
```

Layering: UI → Riverpod providers → Repositories → DAOs → Drift tables.

---

## Migrations

- `schemaVersion` starts at 1. Bump for every schema change.
- Use incremental `if (from < N)` checks in `onUpgrade`.
- `onCreate` calls `m.createAll()` + enables `PRAGMA foreign_keys = ON` + `PRAGMA journal_mode = WAL`.
- Always test migrations with in-memory databases.

---

## Generated Code

- `*.g.dart` and `*.drift.dart` files are listed in `.gitignore`.
- Run `dart run build_runner build --delete-conflicting-outputs` after pulling changes.
- CI (future) should include the build_runner step.

---

## Testing

Use `NativeDatabase.memory()` for unit tests:

```dart
db = AppDatabase.forTesting(NativeDatabase.memory());
```

Important: Drift stores `DateTime` columns as **seconds** since epoch, not milliseconds. Assertions on timestamp ordering require ≥1 second delays between writes.

---

## Query Patterns

- **Home page sections**: `watchContinuing` / `watchRecentlyAdded` / `watchRecentlyFinished` — join `media_items` + `user_entries`, filter by status + deletedAt.
- **Library**: `watchLibrary` — filter by `mediaType` + `status`, sort by `updatedAt` / `title` / `score`.
- **Detail**: `watchItem` + separate DAO calls for progress/tags/shelves.
- **Joins**: Use `select().join([leftOuterJoin(...)])` for composed results; map with `row.readTable()` / `row.readTableOrNull()`.

---

## Common Mistakes

- Using `intEnum<T>()` for enums that participate in sync — use text-based TypeConverter instead.
- Forgetting to import converter classes in `app_database.dart` — the generated code references them.
- Calling `delete()` on business tables instead of `softDelete()`.
- Using auto-increment IDs — UUID v4 is required for sync compatibility.
- Creating `DateTime` columns without considering second-level precision in tests.
