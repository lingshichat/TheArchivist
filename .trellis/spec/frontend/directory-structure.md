# Directory Structure

> How frontend code is organized in this project.

---

## Overview

This repository currently ships a single Flutter application at repo root.
Code is organized by **app shell**, **feature modules**, and **shared building blocks**.

The immediate goal for Phase 1 is to keep the Windows-first shell, theme tokens,
and page skeletons easy to evolve without mixing them with data-layer work.

The visual contract comes from the Stitch "The Archivist" desktop references.
That means shell geometry, page composition, and token ownership should remain
obvious in the directory layout.

---

## Directory Layout

```text
lib/
├── app/
│   ├── app.dart
│   ├── router/
│   │   └── app_router.dart
│   └── shell/
│       └── app_shell_scaffold.dart
├── features/
│   ├── detail/presentation/detail_page.dart
│   ├── home/presentation/home_page.dart
│   ├── library/presentation/library_page.dart
│   └── settings/presentation/settings_page.dart
├── shared/
│   ├── demo/demo_data.dart
│   ├── theme/app_theme.dart
│   └── widgets/
│       ├── app_top_bar.dart
│       ├── poster_card.dart
│       ├── poster_wrap.dart
│       ├── section_card.dart
│       └── section_header.dart
└── main.dart
```

---

## Module Organization

- `app/`
  - Owns application bootstrap, routing, and the global shell layout.
  - Must not contain feature-specific presentation details beyond shell concerns.
- `features/<feature>/presentation/`
  - Owns feature-facing page composition.
  - Phase 1 keeps feature files UI-first and data-light.
- `shared/theme/`
  - Owns design tokens and `ThemeData`.
  - Any visual token change should start here.
  - Stitch-derived colors, typography, radius, and spacing contracts belong here.
- `shared/widgets/`
  - Holds reusable UI pieces that are used by 2+ pages.
  - Shell and desktop primitives should live here instead of staying embedded
    inside page files once reused.
- `shared/demo/`
  - Temporary demo data for skeleton and layout work.
  - Replace or shrink once local data integration lands in later work packages.

---

## Naming Conventions

- Use `snake_case.dart` for files.
- Use singular feature folder names like `home`, `library`, `detail`, `settings`.
- Keep route, shell, and theme entry files explicit:
  - `app_router.dart`
  - `app_shell_scaffold.dart`
  - `app_theme.dart`
- Reusable widgets should be named after what they render, not where they are used.
- Prefer names that describe the Stitch contract they implement:
  - `archivist_sidebar.dart`
  - `archivist_top_bar.dart`
  - `poster_tile.dart`
  - `filter_strip.dart`

---

## Design Ownership Rules

- `app/shell/`
  - Owns sidebar width, top bar offset, shell breakpoints, and active-route shell state.
- `shared/theme/`
  - Owns exact visual tokens.
  - Must not approximate Stitch colors with `ColorScheme.fromSeed` as the final source.
- `shared/widgets/`
  - Owns reusable surface blocks such as navigation items, poster tiles, segmented controls,
    settings panels, metadata rows, and archive badges.
- `features/*/presentation/`
  - Compose pages from shared shell/theme/widgets.
  - Must not redefine page-level spacing, card radius, or shell chrome ad hoc.

---

## Examples

- App entry and shell:
  - `lib/app/app.dart`
  - `lib/app/shell/app_shell_scaffold.dart`
- Feature pages:
  - `lib/features/home/presentation/home_page.dart`
  - `lib/features/detail/presentation/detail_page.dart`
- Shared visual building blocks:
  - `lib/shared/theme/app_theme.dart`
  - `lib/shared/widgets/poster_card.dart`
