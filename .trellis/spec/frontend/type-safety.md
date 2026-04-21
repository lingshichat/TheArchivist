# Type Safety

> Type safety patterns in this project.

---

## Overview

This is a Dart 3.10+ Flutter project. Strict null safety is always on.
Type decisions are driven by the codebase's actual patterns — hand-written
DTOs, sealed error hierarchies, and domain enums defined in `shared/data/`.

---

## DTO Pattern (Hand-written)

All API / transport-layer DTOs use **hand-written** `fromJson` / `toJson`.
No code generation (`json_serializable`, `freezed`, `built_value`) for DTOs.

Rules:

- Immutable: `final` fields, `const` constructor where possible
- Single file per domain: e.g. `bangumi_models.dart` groups all Bangumi DTOs
- Factory `fromJson(Map<String, dynamic> json)` + `Map<String, dynamic> toJson()`
- Unknown JSON keys are silently ignored (defensive parsing)
- Nullable fields map to `null` when the JSON key is absent, not to sentinel values

```dart
class BangumiSubjectDto {
  final int id;
  final String name;
  final String? nameCn;
  final String? summary;
  final int? type;
  final String? date;
  final BangumiImageDto? image;

  const BangumiSubjectDto({
    required this.id,
    required this.name,
    this.nameCn,
    this.summary,
    this.type,
    this.date,
    this.image,
  });

  factory BangumiSubjectDto.fromJson(Map<String, dynamic> json) =>
      BangumiSubjectDto(
        id: json['id'] as int,
        name: json['name'] as String,
        nameCn: json['name_cn'] as String?,
        summary: json['summary'] as String?,
        type: json['type'] as int?,
        date: json['date'] as String?,
        image: json['image'] != null
            ? BangumiImageDto.fromJson(json['image'] as Map<String, dynamic>)
            : null,
      );
}
```

Why hand-written:

- DTOs are small (5–10 classes per integration), one-time cost is low
- No extra build_runner dependency per integration module
- Field rename (`name_cn` → `nameCn`) is explicit and grep-friendly
- Drift tables already use code generation; DTOs stay lightweight

---

## Error Types (Sealed Class)

All error hierarchies use **Dart 3 `sealed class`** with named subclasses.

Rules:

- One `sealed class` per error domain (e.g. `BangumiApiException`)
- Subclasses are `final` and carry only relevant fields
- Pattern matching on `switch` is exhaustive — compiler enforces coverage
- No error codes as integers — use named constructors or named subclasses

```dart
sealed class BangumiApiException implements Exception {
  final String message;
  const BangumiApiException(this.message);
}

final class BangumiNetworkError extends BangumiApiException {
  const BangumiNetworkError([super.message = 'Network error']);
}

final class BangumiUnauthorizedError extends BangumiApiException {
  final int? statusCode;
  const BangumiUnauthorizedError(this.statusCode)
      : super('Unauthorized ($statusCode)');
}

final class BangumiNotFoundError extends BangumiApiException {
  const BangumiNotFoundError([super.message = 'Not found']);
}

final class BangumiServerError extends BangumiApiException {
  final int statusCode;
  const BangumiServerError(this.statusCode) : super('Server error $statusCode');
}

final class BangumiUnknownError extends BangumiApiException {
  final int? statusCode;
  const BangumiUnknownError([this.statusCode, super.message = 'Unknown error']);
}
```

---

## Domain Enums

Domain enums live in `lib/shared/data/tables/enums.dart`.

Rules:

- Enums are simple (no attached methods); mapping logic lives in dedicated mappers
- Mappers (`BangumiTypeMapper`, etc.) are pure functions or static-method classes
- Bidirectional mapping: `fromExternal(T) → LocalEnum` and `toExternal(LocalEnum) → T`
- Throw `ArgumentError` on unrecognized values — never silently default

Current enums:

- `MediaType { movie, tv, book, game }`
- `UnifiedStatus { wishlist, inProgress, done, onHold, dropped }`
- `ActivityEvent { added, statusChanged, scoreChanged, progressChanged, noteEdited, completed }`

---

## Null Safety Rules

- Never use `!` (null assertion) on values that come from external sources (JSON, API, user input)
- Use `as int?` / `as String?` when parsing JSON, never bare `as int`
- Prefer `?.` chains over `if (x != null) x.foo()`
- Database nullable columns map to Dart nullable types — do not invent sentinel defaults

---

## Forbidden Patterns

- Using `dynamic` in public API signatures (acceptable only in internal `fromJson` parsing)
- Using `Object` as a catch-all type instead of proper generics
- Generating DTOs with `json_serializable` / `freezed` without team consensus to change this guideline
- Defining domain enums outside `lib/shared/data/tables/enums.dart` without a clear reason
- Using `late` on fields that can remain nullable — `late` is only for injected dependencies guaranteed by framework lifecycle

---

## Common Mistakes

- Forgetting to test mapper round-trips (`fromExternal(toExternal(x)) == x`)
- Treating missing JSON keys as errors instead of null — most external APIs return partial data
- Adding a new enum variant in one place but forgetting the mapper — always add both the enum value AND the mapper case together
