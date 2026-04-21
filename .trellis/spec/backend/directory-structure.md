# Directory Structure

> How backend code is organized in this project.

---

## Overview

This repository does not have a traditional server backend.

For this project, "backend" means:

- local persistence and sync-facing code in the Flutter app
- external integration services and transport clients
- Trellis automation scripts under `.trellis/scripts/`

The goal is to keep page code thin while non-UI logic stays in predictable
locations.

---

## Scenario: Placing non-UI runtime code

### 1. Scope / Trigger

Use this spec when adding or moving any of:

- repositories, DAOs, Drift tables
- integration services, DTOs, mappers, feature-local providers
- shared transport clients
- Trellis script helpers

### 2. Signatures

Representative file and type signatures:

```text
lib/shared/data/
  app_database.dart
  providers.dart
  tables/
  daos/
  repositories/

lib/shared/network/
  <provider>_api_client.dart

lib/features/<feature>/data/
  <feature>_controller.dart
  <integration>_api_service.dart
  providers.dart

.trellis/scripts/
  common/
  hooks/
  multi_agent/
```

Representative runtime signatures:

```dart
final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(ref.watch(appDatabaseProvider));
});

class DetailActionsController {
  Future<void> saveChanges(String mediaItemId, DetailEntryUpdateInput input);
}
```

### 3. Contracts

#### Flutter runtime placement

- `lib/shared/data/tables/`
  - schema and converters only
- `lib/shared/data/daos/`
  - SQL/query composition and raw DB joins
- `lib/shared/data/repositories/`
  - write ownership, sync-field stamping, multi-DAO coordination
- `lib/shared/data/providers.dart`
  - cross-feature providers only
- `lib/shared/network/`
  - transport config, auth/header injection, interceptors
- `lib/features/<feature>/data/`
  - feature controllers, integration-specific providers, DTOs, service wrappers

#### Trellis automation placement

- `.trellis/scripts/common/`
  - shared utilities reused by multiple scripts
- `.trellis/scripts/hooks/`
  - lifecycle hooks
- `.trellis/scripts/multi_agent/`
  - worktree / multi-agent orchestration
- top-level script files
  - CLI entrypoints only, with minimal glue logic

### 4. Validation & Error Matrix

| New code | Put it here | Reject if |
|----------|-------------|-----------|
| Cross-feature repository provider | `lib/shared/data/providers.dart` | provider is feature-specific |
| Bangumi auth/search provider | `lib/features/bangumi/data/providers.dart` | provider is added to `shared/data/providers.dart` |
| Shared transport client | `lib/shared/network/` | page/widget imports `dio` directly |
| Multi-step mutation orchestration | feature controller in `features/*/data/` | page performs repository/DAO choreography inline |
| Reused script helper | `.trellis/scripts/common/` | duplicated into multiple entrypoints |

### 5. Good / Base / Bad Cases

#### Good

- `AddEntryController` orchestrates local write side effects
- `MediaRepository` owns DB write details
- Bangumi integration lives under `shared/network/` + `features/bangumi/data/`

#### Base

- feature-only helpers stay local until reuse becomes clear

#### Bad

- page imports DAO or `dio`
- repo code depends on `BuildContext`, `WidgetRef`, or widget classes
- shared provider registry becomes a dump for feature-local integrations

### 6. Tests Required

- `flutter analyze lib test`
- `flutter test`
- Search-based review when moving boundaries:
  - no `dio` import in `presentation/`
  - no DAO import in `presentation/`
  - no duplicated helper logic across `.trellis/scripts/` entrypoints

### 7. Wrong vs Correct

#### Wrong

```dart
class LibraryPage extends ConsumerWidget {
  Future<void> onPressed(WidgetRef ref) async {
    await ref.read(appDatabaseProvider).userEntryDao.updateStatus(...);
  }
}
```

#### Correct

```dart
class DetailActionsController {
  Future<void> applyQuickStatus(
    String mediaItemId,
    UnifiedStatus status,
  ) async {
    await _userEntryRepository.updateStatus(mediaItemId, status);
    await _activityLogRepository.appendEvent(...);
  }
}
```

---

## Naming Conventions

- Use `snake_case.dart` for files
- Keep integration modules named after the provider (`bangumi_*`)
- Prefer `*_controller.dart`, `*_repository.dart`, `*_dao.dart`,
  `*_api_client.dart`, and `*_api_service.dart`
- Keep script helpers small and named after their responsibility, not the
  calling script
