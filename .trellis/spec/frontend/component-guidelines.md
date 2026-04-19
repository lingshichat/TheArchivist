# Component Guidelines

> How components are built in this project.

---

## Overview

Phase 1 uses Flutter widgets, but the rendered result must follow the Stitch
"The Archivist" desktop composition rather than exposing default Material
surfaces.

Component design goals:

- Keep desktop shell chrome custom and predictable.
- Prefer calm, dense, content-first layout blocks over mobile-style scaffolds.
- Extract shared widgets when the same visual contract appears on 2+ pages.
- Keep shell/layout concerns separate from page-specific composition.

---

## Source of Truth

- Global visual tokens: `shared/theme/app_theme.dart`
- Shell contract: `app/shell/app_shell_scaffold.dart`
- Visual reference: Stitch "The Archivist" desktop screens
- Stitch design system asset: `assets/2ebc2aed509941f7a4af99a284c7958a`
- Stitch design theme: `Stoa Editorial` / `The Quiet Archivist`
- Temporary local exports, when present:
  - `.codex-temp/stitch-html/home-v2.html`
  - `.codex-temp/stitch-html/library.html`
  - `.codex-temp/stitch-html/detail.html`
  - `.codex-temp/stitch-html/settings.html`

When a Flutter screen and a Stitch reference disagree, update the Flutter
composition or the spec. Do not silently drift.

---

## Design Intent

Component work must preserve the Stitch editorial feel:

- quiet desktop archive, not playful mobile app chrome
- tonal layering before border/shadow layering
- precise, dense, Windows-first geometry
- media-first composition where covers and titles lead

If a component looks like stock Material after implementation, it is not done.

---

## Required Component Families

### 1. Shell Primitives

Required for the desktop shell:

- Fixed left sidebar with explicit active state
- Sticky top bar with search input and lightweight actions
- Custom navigation item row

Do not use `NavigationRail`, `NavigationDrawer`, or default `AppBar` as the
final rendered shell.

### 2. Content Primitives

Required for archive-heavy pages:

- Poster tile / poster wall item
- Section heading with lightweight uppercase action label
- Metadata badge / status badge
- Surface block for grouped content
- Quiet stat tile / timeline row for detail surfaces

Poster tiles must keep a `2:3` cover ratio and a dense desktop grid feel.

### 3. Form and Settings Primitives

Required for settings and detail actions:

- Search field with leading icon and low-surface fill
- Segmented control or status strip
- Low-contrast select / filter container
- Primary and secondary action rows without Material elevation-heavy styling
- Grouped settings panel with calm local-data emphasis
- Compact confirmation toast for save/sync feedback

### 4. Top-Bar and Search Primitives

Required for Stitch-aligned desktop chrome:

- Top bar container that can support glass-like styling
- Search field container that can support glass-like styling
- Lightweight action icon cluster

Glass treatment belongs here only. Do not turn ordinary cards into frosted UI.

---

## Component Structure

Recommended shape:

1. Public widget class
2. Required constructor parameters
3. `build` method
4. Local private helper widgets only when they are page-specific

Shared widgets belong in `lib/shared/widgets/`.
Feature-only helpers can stay inside the feature page file.

---

## Props Conventions

- Keep widget APIs small and explicit.
- Prefer required named parameters for primary inputs.
- Use `VoidCallback?` for tap actions on presentation components.
- Pass domain-light view data into reusable widgets instead of raw maps.
- Pass explicit visual state instead of letting widgets infer it from routes or globals.

Example:

- `SidebarNavItem(label: 'Library', icon: Icons.grid_view_rounded, isActive: true)`
- `PosterTile(item: item, statusLabel: 'In Progress', onTap: ...)`
- `SettingsPanel(title: 'Local Data', trailingBadge: 'Current: Local Mode')`

---

## Styling Patterns

- Styling is centralized through `lib/shared/theme/app_theme.dart`.
- Use exact token classes such as:
  - `AppColors`
  - `AppSpacing`
  - `AppRadii`
  - shared text styles derived from Inter + Manrope
- Avoid redefining spacing, border radius, or surface colors ad hoc inside pages.
- Keep shadows minimal and secondary to surface contrast.
- Reuse shared widgets for repeated surface treatments and section headers.
- Labels should generally be uppercase, compact, and tracking-wide when they behave
  like metadata, status, or filter copy.
- Use surface shifts before borders to separate groups.
- Keep structural radii sharp; reserve softer/floating radii for pills, toasts,
  and emphasis controls.
- Use radius by surface role:
  - `AppRadii.card` for poster tiles, compact buttons, and input outlines
  - `AppRadii.container` for top-bar search shells and grouped desktop chrome
  - `AppRadii.pill` only for true pill/avatar treatments
- Use gradients only for primary emphasis moments, not generic component fill.
- Keep list separation whitespace-based; avoid default divider habits.

Example:

```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.surfaceContainerLow,
    borderRadius: BorderRadius.circular(AppRadii.card),
    border: Border.all(
      color: AppColors.outlineVariant.withValues(alpha: 0.15),
    ),
  ),
  child: const PosterTile(...),
)
```

---

## Stitch-Derived Component Contracts

### Top-Bar Layout Contract

- Build the desktop top bar from fixed slots, not intrinsic title width.
- Home / Library / Settings reuse the same geometry:
  - title slot: `188px`
  - search gap: `24px`
  - search width: `360px`
  - search height: `34px`
  - action target: `36px`
- Route variants may change copy, hint text, or title color, but should not
  change the search anchor without an explicit design-spec update.
- Home / Library / Settings titles use the same black editorial title style.
- Detail may keep the branded accent title while reusing the same geometry.
- Backdrop blur belongs to the top bar only.

### No-Line Contract

- Do not use strong 1px dividers as the default grouping mechanism.
- Prefer `surface`, `surfaceContainerLow`, and `surfaceContainerLowest`
  transitions.
- If a border is required, keep it ghosted near `outlineVariant` low opacity.
- Local exception: a single underline inside a tab/filter band is acceptable
  when it stays faint and does not become the page's main grouping mechanism.

### Tonal Layering Contract

- Build hierarchy by nesting tone tiers.
- Common good pattern:
  `surfaceContainerLowest` card inside `surfaceContainerLow` section.
- Avoid card stacks that rely on heavy elevation and long shadows.

### Glass Contract

- Glass styling is allowed only for top bar and search-related containers.
- Keep it restrained and editorial.
- Do not reuse it for library cards, settings groups, or detail panels.

### Gradient Contract

- Allowed for primary CTA or rare hero emphasis.
- Do not gradient-fill secondary buttons, filter pills, or ordinary panels.

### Typography Contract

- `Manrope` leads titles, section heads, and hero text.
- `Inter` leads metadata, controls, and utility copy.
- Category-like labels should stay uppercase and tracked.

---

## Desktop Layout Rules

- Desktop pages should open directly into working content, not an invented
  onboarding hero. Use an editorial greeting block only when the Stitch
  reference explicitly shows one.
- Preserve lateral whitespace and dense vertical stacking similar to Stitch.
- Library and home pages should feel like archival surfaces, not card carousels.
- Detail and settings pages should prefer two-column desktop composition over
  long single-column mobile stacking at large widths.
- Components should align to shared gutters instead of centering like mobile cards.
- Large titles may sit asymmetrically when the reference screen does so.

### Library Intro Pattern

- Library keeps the chrome title as `Library`, but the page body opens with an
  editorial greeting instead of repeating the route label.
- Use this pattern:
  - display title for greeting
  - body subtitle for collection stats
  - shared control band for tabs + filters
- Desktop behavior:
  - row layout when width is approximately `920px` or above
  - stacked layout below that breakpoint
- The "load more" control should read like archive utility UI:
  uppercase label, tracked text, thin ghost border, no large Material button
  treatment

---

## Accessibility

- Keep visible labels for primary desktop actions.
- Do not rely on icon-only meaning for important navigation.
- Preserve readable contrast for low-saturation surfaces and text.
- Use large enough click targets for desktop controls and pills.

---

## Wrong vs Correct

### Wrong

```dart
Card(
  child: ListTile(
    leading: const Icon(Icons.search),
    title: const Text('Quick Search'),
  ),
)
```

Why it is wrong:

- It imports stock Material surface language into a Stitch-controlled screen.
- It relies on generic card/list styling instead of explicit editorial geometry.
- It encourages divider, padding, and radius defaults that drift from the spec.

### Correct

```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.surfaceContainerLow,
    borderRadius: BorderRadius.circular(AppRadii.card),
    border: Border.all(
      color: AppColors.outlineVariant.withValues(alpha: 0.15),
    ),
  ),
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  ),
  child: const Row(
    children: [
      Icon(Icons.search_rounded, size: 16),
      SizedBox(width: AppSpacing.sm),
      Expanded(child: Text('Search your archive')),
    ],
  ),
)
```

Why it is correct:

- Geometry, tone, and border strength are explicit.
- The surface reads like Stitch chrome instead of generic Material.
- It can be reused across shell and page contexts without visual drift.

---

## Common Mistakes

- Mixing shell code and feature page code in the same file
- Repeating slightly different section containers instead of reusing a shared surface block
- Hardcoding colors in feature pages instead of using theme tokens
- Treating desktop settings and library pages like mobile list screens
- Using large-radius Material cards that make the UI softer than Stitch
- Using generic chips, FABs, drawers, or elevated buttons as visible final UI
- Using divider lines where Stitch expects whitespace and tonal grouping
- Applying glass or gradients to ordinary content panels
- Letting search, filter, and badge widgets drift into playful mobile styling
