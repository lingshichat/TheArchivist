# Design System

> Stitch-derived visual contract for the Windows-first Flutter shell.

---

## Overview

Phase 1 should look like the Stitch "The Archivist" desktop screens.
The design system in this file is the implementation contract between Stitch
reference output and Flutter widgets.

This spec exists to prevent "close enough Material" drift.

---

## App Identity

Brand name, platform identifiers, and icon contract. These values are locked
for Phase 1 and must stay consistent across all platform manifests and window
chrome.

### Brand Name

| Scope | Value |
|-------|-------|
| Display name | `The Archivist` |
| Dart package name | `record_anywhere` (pubspec.yaml, internal only) |
| Database name | `record_anywhere` (drift, internal only) |

### Android

| Field | Value |
|-------|-------|
| `applicationId` | `com.thearchivist.app` |
| `namespace` | `com.thearchivist.app` |
| `android:label` | `The Archivist` |
| Kotlin package | `com.thearchivist.app` |
| Source path | `android/app/src/main/kotlin/com/thearchivist/app/MainActivity.kt` |

### Windows

| Field | Value |
|-------|-------|
| Native window title (`main.cpp`) | `The Archivist` |
| `ProductName` (`Runner.rc`) | `The Archivist` |
| `FileDescription` (`Runner.rc`) | `The Archivist` |
| `CompanyName` (`Runner.rc`) | `com.thearchivist.app` |
| Binary name (`CMakeLists.txt`) | `record_anywhere.exe` (unchanged) |

### Flutter MaterialApp

```dart
// lib/app/app.dart
MaterialApp.router(
  title: 'The Archivist',
  ...
);
```

### App Icon

| Attribute | Value |
|-----------|-------|
| Stitch screen ID | `84ddc0a6017547d79d5bb399eb8a5acf` |
| Generated | `2026-04-25` (v1, cropped to inner card) |
| Description | Geometric "A" monogram on cream rounded-square card. Outer gray background cropped off, card edge is the icon boundary. |
| Description | Geometric "A" monogram built from book/archive imagery, ink-green on cream |
| Android densities | mdpi (48), hdpi (72), xhdpi (96), xxhdpi (144), xxxhdpi (192) |
| Windows ICO sizes | 16, 32, 48, 256 |

To regenerate the icon, use the Stitch screen as the reference and export
to the platform-specific formats listed above. Do not replace with a generic
Material icon or an approximate recreation.

---


- Primary reference: Stitch project `16942033954476618867`
- Design system asset: `assets/2ebc2aed509941f7a4af99a284c7958a`
- Design system display name: `Stoa Editorial`
- Stitch theme north star: `The Quiet Archivist`
- Last confirmed against live Stitch state: `2026-04-19`
- Reference screens:
  - Home
  - Library
  - Detail
  - Settings
- Local HTML snapshots, when available:
  - `.codex-temp/stitch-html/home-v2.html`
  - `.codex-temp/stitch-html/library.html`
  - `.codex-temp/stitch-html/detail.html`
  - `.codex-temp/stitch-html/settings.html`

If the local HTML cache disappears, regenerate the screen exports from Stitch.
Do not replace this design system with approximate recollection.

---

## Stitch Theme Snapshot

This spec is synchronized from the Stitch project theme metadata, not only from
screen screenshots.

Confirmed Stitch theme fields on `2026-04-19`:

- `designMd`: editorial guidance for "The Quiet Archivist"
- `namedColors`: full token palette including `primary_dim`,
  `surface_container_lowest`, and `outline_variant`
- `headlineFont`: `MANROPE`
- `bodyFont`: `INTER`
- `labelFont`: `INTER`
- `roundness`: `ROUND_FOUR`
- `spacingScale`: `3`
- `colorMode`: `LIGHT`

When the Stitch design theme changes, update this file and
`lib/shared/theme/app_theme.dart` in the same work item.

---

## Design Decision: Stitch theme + screens are the visual contract

**Context**

The first Flutter shell draft looked structurally correct but visually drifted
from the approved Stitch screens. The main failure mode was using default
Material layout primitives and seed-generated theme values instead of the
actual reference geometry, theme tokens, and editorial rules.

**Decision**

Use Stitch as the visual contract for:

- token values
- surface philosophy
- shell geometry
- page composition
- hover/active/selected treatments
- density and whitespace
- component-level styling rules from `designMd`

**Non-goals**

- Translating Stitch HTML directly into production Flutter code
- Treating Tailwind classes as runtime dependencies
- Rebuilding every tiny animation before the static layout is faithful

### Design Decision: fixed-slot top bar geometry

**Context**

Earlier Flutter drafts let the search field drift horizontally because the title
width and page-specific padding changed per route. That made Home, Library, and
Settings look like different shells even when they were meant to share the same
desktop chrome.

**Decision**

Keep the top bar as a fixed-slot layout:

- title slot stays fixed
- search field starts at a fixed anchor
- trailing action stays at a fixed anchor
- route variants change copy and palette first, not geometry

**Route rule**

- Home / Library / Settings share the same slot widths and black editorial title
- Detail may keep the accent-ink title, but it should still reuse the same slot
  geometry

**Why**

This prevents title-length drift and keeps Stitch desktop alignment stable.

---

## Editorial North Star

The approved Stitch theme is not "generic desktop Material". It is an editorial,
Windows-first archive workspace.

Required qualities:

- quiet, archival, low-noise presentation
- intentional asymmetry where hero text or dense content needs rhythm
- tonal depth before shadow depth
- dense, precise desktop composition instead of spacious mobile cards
- content curation feel rather than dashboard or streaming-service feel

Reject if the page feels:

- like default Material 3 chrome
- like a mobile layout stretched onto desktop
- like an app-store marketing page
- dependent on thick dividers, bright gradients, or large shadows for hierarchy

---

## Non-Negotiable Stitch Rules

### No-Line Rule

- Do not use standard 1px section dividers as the main grouping mechanism.
- Define sections through surface changes first.
- If a boundary is required for accessibility, use `outlineVariant` at low
  opacity only.

### Tonal Layering Rule

- Prefer hierarchy through `surface` / `surfaceContainer*` stacking.
- A raised card should usually be
  `surfaceContainerLowest` inside `surfaceContainerLow` or `surfaceContainer`.
- Shadows are secondary and should remain soft and low-contrast.

### Glass & Gradient Rule

- Glass treatment is reserved for the desktop top bar and search containers.
- Primary-to-dim gradients are reserved for the most important CTA or hero-like
  emphasis only.
- Do not spread gradient fills across general cards, lists, or settings panels.

### Desktop Precision Rule

- Structural surfaces stay sharp: `sm` to `card` radius.
- Larger radii belong only to floating or emphasis elements.
- Avoid oversized buttons, bottom-sheet-like treatments, and soft mobile chrome.

### Typography Rule

- Use `Manrope` for display and headline roles.
- Use `Inter` for body, metadata, controls, and labels.
- Keep `Manrope` scoped to actual title semantics only:
  - page titles
  - section titles
  - card/dialog titles
- Do not use `Manrope` for:
  - toast / snackbar copy
  - inline status text
  - button labels
  - form fields or helper text
- Metadata labels should look cataloged: compact, uppercase, tracked.
- Never use pure black text; use `onSurface`.

---

## Token Contract

### Core Colors

Use these values as the shared baseline unless a later approved design update
replaces them.

| Token | Value | Use |
|------|------|-----|
| `background` | `#F9F9FB` | app background |
| `surface` | `#F9F9FB` | page surface |
| `surfaceContainerLowest` | `#FFFFFF` | bright inner surfaces |
| `surfaceContainerLow` | `#F2F4F6` | search bars, grouped controls |
| `surfaceContainer` | `#EBEEF2` | poster tiles, low-emphasis panels |
| `surfaceContainerHigh` | `#E4E9EE` | segmented control base |
| `surfaceContainerHighest` | `#DDE3E9` | avatar / stronger neutral surfaces |
| `onSurface` | `#2D3338` | primary text |
| `onSurfaceVariant` | `#596065` | body-supporting text |
| `outline` | `#757C81` | stronger outline |
| `outlineVariant` | `#ACB3B8` | soft outline |
| `primary` | `#426464` | accents, active state |
| `primaryDim` | `#365858` | active hover / stronger accent |
| `primaryContainer` | `#C5EAE9` | selected state fill |
| `onPrimary` | `#DAFFFE` | text on primary |
| `secondary` | `#5C605F` | muted secondary ink |
| `secondaryContainer` | `#E0E3E2` | neutral badges / secondary surfaces |
| `secondaryDim` | `#505453` | stronger neutral utility surfaces |
| `secondaryFixedDim` | `#D2D5D4` | unselected filter chips |
| `surfaceDim` | `#D3DBE2` | stronger dim background moments |
| `surfaceVariant` | `#DDE3E9` | neutral container variant |
| `tertiaryContainer` | `#D9F9DF` | tertiary status accents |
| `error` | `#9F403D` | error state |

### Token Mapping to Flutter Theme

The Flutter theme should preserve Stitch token ownership explicitly.

| Stitch token | Flutter token |
|------|------|
| `primary` | `AppColors.accent` |
| `primary_dim` | `AppColors.accentStrong` |
| `primary_container` | `AppColors.accentContainer` |
| `on_primary` | `AppColors.accentForeground` |
| `surface_container_low` | `AppColors.surfaceContainerLow` |
| `surface_container` | `AppColors.surfaceContainer` |
| `surface_container_high` | `AppColors.surfaceContainerHigh` |
| `surface_container_highest` | `AppColors.surfaceContainerHighest` |
| `outline_variant` | `AppColors.outlineVariant` |
| `on_surface_variant` | `AppColors.onSurfaceVariant` |

### Typography

- Headline family: `Manrope`
- Body family: `Inter`
- Labels: `Inter`

Required hierarchy:

- Brand / page title: `Manrope`, bold to extra-bold, tight tracking
- Section title: `Manrope`, bold
- Body copy: `Inter`, regular to medium
- Metadata / filters / state labels: `Inter`, uppercase, `10px` to `12px`,
  wide tracking

Do not use Flutter default headline/body proportions as the final hierarchy.

Specific Stitch intent:

- Display titles should feel book-like and tight-tracked.
- `body-md` is the default metadata workhorse.
- Strong hierarchy comes from contrast between large editorial titles and small
  utility labels.

### Radius

Use a restrained radius scale:

| Token | Value |
|------|------|
| `sm` | `2px` |
| `lg` | `4px` |
| `xl` | `8px` |
| `full` | `12px` |

The reference is sharper than common mobile-first Material styling.

Roundness is derived from Stitch `ROUND_FOUR`, so structural containers should
cluster around the `4px` family rather than Material-soft `12px` to `16px`
cards.

### Spacing

Preferred desktop rhythm:

- Sidebar horizontal padding: `32px`
- Main page horizontal padding: `48px`
- Section-to-section gap: `32px`
- Card / panel inner padding: `24px`
- Compact metadata rows: `8px` to `12px`

Spacing scale `3` means density should stay deliberate and desktop-first. Avoid
adding empty hero spacing unless the Stitch screen clearly uses it.

---

## Desktop Layout Contract

### Shell

- Left sidebar width: `256px`
- Sidebar is fixed on desktop
- Top bar is sticky and aligned with the content area, not the full viewport
- Top bar height: approximately `64px`
- Top bar max width: `1600px`
- Main content max width:
  - Home / Library: `1600px`
  - Detail: `1440px`
  - Settings: `1280px`
- Settings content background uses `shellPanel`, not the brighter page
  background
- Main content uses generous horizontal padding and dense internal grids

### Top Bar Geometry

Shared desktop header geometry:

- horizontal padding: `48px`
- vertical padding: `16px`
- title slot width: `188px`
- search gap after title: `24px`
- search field target width: `360px`
- search shell height: `34px`
- trailing action tap target: `36px`

Shared title behavior:

- Home: `Home`
- Library: `Library`
- Settings: `Settings`
- Home / Library / Settings use `onSurface` as title ink
- Detail keeps the branded `The Archivist` title in `accentStrong`

Do not use slash-separated bilingual titles in the desktop top bar once the
Stitch copy has been locked.

### Home

- Opens directly into working content
- No greeting hero or onboarding block
- Section order:
  1. Continuing
  2. Recently Added
  3. Recently Finished
  4. Categories
- Posters use dense grids with `2:3` covers

### Library

- Dense poster wall is the main event
- Includes:
  - top-bar title `Library`
  - greeting hero title
  - stats subtitle
  - media-type tabs
  - filter row
  - sort controls
  - multi-column desktop grid
- Hero copy uses:
  - title: `Welcome back, Elias.`
  - subtitle: `Managing 1,248 items across your personal archive.`
- Tabs and filters belong to one shared control band
- A single low-opacity underline is allowed inside that control band only when
  it helps anchor the controls; it must stay near `outlineVariant` at or below
  `10%` opacity
- Large desktop widths should feel full, not sparse

### Detail

- Use a 12-column desktop composition
- Left column owns:
  - status
  - progress
  - rating
  - primary and secondary actions
- Right column owns:
  - title block
  - synopsis
  - tags
  - notes
  - lifecycle log
  - quick stats

### Settings

- Use a grouped desktop settings board, not a plain list
- Must include visible sections for:
  - appearance
  - logging preferences
  - local data
  - cloud sync
  - app info
- Local data block is highlighted but still calm
- Success feedback can float as a compact toast at bottom-right

#### App Info (About) section

The bottom-most section in Settings, separated from previous sections by a
low-opacity top border.

| Field | Source | Notes |
|-------|--------|-------|
| App icon | `assets/icon.png` | 48×48, rounded corners, same as platform launcher icon |
| Display name | hardcoded | `The Archivist Desktop` |
| Version | must match `pubspec.yaml` `version` field | Currently `0.1.0`; keep in sync manually unless `package_info_plus` is added |
| Copyright | hardcoded | `© 2026 AnyRecord Team.` |
| Description | hardcoded | preservation and curation tagline |

When the pubspec version is bumped for a release, the About version string
must be updated in the same commit.

---

## Signatures

These are not final file names, but they are the minimum design-level interfaces
the Flutter code must cover.

```dart
Widget buildDesktopShell({
  required String currentRoute,
  required Widget child,
});

Widget buildSidebarNavItem({
  required String label,
  required IconData icon,
  required bool isActive,
  VoidCallback? onTap,
});

Widget buildPosterTile({
  required PosterViewData item,
  String? badgeLabel,
  VoidCallback? onTap,
});
```

---

## Contracts

### Navigation Contract

- Active nav item uses the accent color and a stronger background treatment
- Inactive nav items stay low-contrast
- Labels remain visible on desktop
- Sidebar separation should come from surface contrast, not thick borders

### Poster Contract

- Cover area stays at `2:3`
- Text density stays compact
- Hover changes are subtle:
  - slight lift or scale
  - slight color emphasis
  - no dramatic shadow bloom
- Poster image remains the hero; metadata should align tightly to the cover edge

### Search / Filter Contract

- Search uses low-surface fill with a leading icon
- Filters and segmented controls sit on grouped neutral surfaces
- Controls should feel editorial and calm, not app-store playful
- Glass treatment is allowed here, but not as a page-wide effect
- Search should start from the same x-anchor on Home / Library / Settings
- Title length must not push the search field left or right

### Border / Divider Contract

- Do not introduce full-strength section borders into page composition
- Avoid list dividers; use whitespace and tone separation
- If a border is required, keep it near `outlineVariant` at approximately
  `15%` opacity
- Narrow exception: a single underline inside a local tab/filter band may go as
  low as `10%` opacity when it is not used as the primary page grouping device

### Button Contract

- Primary action may use accent emphasis or a subtle primary-to-dim gradient
- Secondary action uses neutral layered surfaces without hard borders
- Tertiary action stays ghost-like and signals hover through tonal change

### Input Contract

- Search may use glass styling
- Standard text inputs should lean minimal and ledger-like rather than pill-heavy
- Focus state should sharpen toward `primary`, not grow into bright glow effects

### Surface Contract

- Surfaces stack through tone changes first
- Borders are soft and often semi-transparent
- Shadows are secondary and restrained
- Floating shadows, when needed, should behave like soft ambient light rather
  than card elevation stacks

### Motion Contract

- Hover and selection transitions should feel subtle and editorial
- Default review target: around `200ms` ease-out
- Hover should shift tone first, not throw long-distance transforms

---

## Validation & Review Matrix

| Area | Required | Reject if |
|------|----------|-----------|
| Sidebar | fixed `256px`, custom item rows, visible active state | looks like `NavigationRail` |
| Top bar | sticky, compact, aligned to content area | spans full page chrome like default `AppBar` |
| Top-bar alignment | Home / Library / Settings share title, search, and action anchors | search start position drifts with title length |
| Dividers | whitespace + tonal grouping | page relies on strong 1px separators |
| Glass usage | only top bar / search areas | glass cards appear everywhere |
| Gradient usage | primary CTA or hero emphasis only | gradients spread across generic UI |
| Colors | exact Stitch palette or approved derived alias | seed-generated approximation drifts |
| Typography | `Manrope` + `Inter` hierarchy | default Material text scale dominates |
| Poster grid | dense multi-column `2:3` grid | sparse card list or carousel feel |
| Detail page | two-column desktop board | long single-column mobile stack at desktop width |
| Settings page | grouped panels + local-data emphasis | plain form list without hierarchy |

---

## Good / Base / Bad Cases

### Good

- Custom sidebar and top bar match the Stitch silhouette
- Tokens are centralized and exact
- Home and library read like archive workspaces
- Detail and settings use desktop grouping and contrast correctly

### Base

- Structure matches Stitch
- Typography and colors mostly match
- A few small hover or spacing details still need refinement

### Bad

- Default Material shell is still visible
- Tokens are approximate
- Page density is too loose
- Home turns into a welcome page
- Library turns into oversized cards

---

## Tests Required

- `flutter analyze lib test`
- `flutter test`
- Manual Windows preview check after any layout or token change

Manual assertions:

1. Sidebar width matches the desktop contract
2. Top bar placement matches the content area
3. Home / Library / Settings share the same top-bar alignment
4. Poster grids keep `2:3` ratio and dense layout
5. Typography uses the approved hierarchy
6. Settings still highlights local-first storage clearly and keeps the
   `shellPanel` background
7. Library hero copy uses greeting + stats, not the old bilingual page title
8. No default Material shell chrome is obvious
9. Page grouping does not depend on strong divider lines
10. Gradients appear only in allowed emphasis areas
11. Glass treatment stays limited to top-bar/search contexts

If screenshot-based or golden testing is introduced later, use this file as the
assertion baseline.

---

## Wrong vs Correct

### Wrong

```dart
final colorScheme = ColorScheme.fromSeed(seedColor: Colors.teal);

return Scaffold(
  appBar: AppBar(title: const Text('Home')),
  body: NavigationRail(
    destinations: const [...],
    selectedIndex: 0,
  ),
);
```

Why it is wrong:

- The shell silhouette is not the Stitch shell.
- Tokens are approximate rather than extracted.
- It produces generic Material chrome.

### Correct

```dart
abstract final class AppColors {
  static const background = Color(0xFFF9F9FB);
  static const surfaceContainerLow = Color(0xFFF2F4F6);
  static const surfaceContainer = Color(0xFFEBEEF2);
  static const outlineVariant = Color(0xFFACB3B8);
  static const onSurface = Color(0xFF2D3338);
  static const primary = Color(0xFF426464);
}

const double kSidebarWidth = 256;

return Row(
  children: [
    const SizedBox(width: kSidebarWidth, child: ArchivistSidebar()),
    Expanded(child: ArchivistPageFrame(child: child)),
  ],
);
```

The point is not to copy this snippet literally. The point is to keep exact
tokens and exact shell geometry as explicit code contracts.
