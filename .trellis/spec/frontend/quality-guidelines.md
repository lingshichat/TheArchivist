# Quality Guidelines

> Code quality standards for frontend development.

---

## Overview

Frontend quality is not just "code compiles". For Phase 1, a change is only
acceptable when it preserves the Stitch-derived desktop visual contract and
keeps the Flutter structure maintainable.

---

## Source of Truth Reminder

Review UI changes against all three sources together:

- `.trellis/spec/frontend/design-system.md`
- live Stitch design system `assets/2ebc2aed509941f7a4af99a284c7958a`
- relevant Stitch screen HTML / screenshot exports

Do not approve a change just because it "looks cleaner" than the current app.
If it departs from Stitch, the burden is on the change author.

---

## Forbidden Patterns

- Using `ColorScheme.fromSeed` output as the final visual source for page chrome
  after exact Stitch tokens are known
- Rendering default `NavigationRail`, `Drawer`, `AppBar`, `Card`, or `ListTile`
  surfaces as final desktop UI
- Introducing new ad hoc colors, radii, or page gutters inside feature pages
- Replacing dense poster grids with large mobile cards or wide empty hero sections
- Using strong drop shadows, oversized rounding, or saturated accents that drift
  from the Stitch tone
- Reintroducing hard divider lines where Stitch grouping depends on whitespace
  and tonal shifts
- Applying glassmorphism outside top-bar and search contexts
- Applying gradients to generic cards, filters, badges, or settings groups
- Using pure black text or high-contrast border-heavy containers
- Committing unreadable mojibake or broken UI copy
- Mixing shell route state and page-only UI state in the same widget without a
  clear boundary

Why these are forbidden:

- They create visual drift from the approved design source.
- They make later screen-by-screen translation from Stitch harder.
- They hide layout contracts inside one-off widgets.

---

## Required Patterns

- Keep exact visual tokens in `shared/theme/` and reference them from pages/widgets
- Build the desktop shell from custom layout primitives
- Keep poster items at `2:3` ratio unless a page contract explicitly says otherwise
- Keep navigation, headers, filters, badges, and grouped settings blocks reusable
- Verify active/hover/selected states against the Stitch reference before merging
- Prefer subtle borders and layered surfaces over heavy shadows
- Keep page composition desktop-first at widths used for Windows preview
- Prefer tonal layering over divider-based separation
- Restrict glass treatment to the global top bar and search surfaces
- Restrict gradient treatment to primary emphasis moments only
- Keep structural radii sharp and desktop-like
- Keep labels editorial: compact, uppercase when used as metadata

Example baseline:

```dart
const double kSidebarWidth = 256;
const double kDesktopGutter = 48;
const double kTopBarHeight = 64;
```

---

## Testing Requirements

Minimum:

- `flutter analyze lib test`
- `flutter test`

When shell geometry, page composition, or tokens change:

- Add or update widget tests for route shell state when practical
- Capture Windows preview screenshots or equivalent manual comparison against
  the Stitch screen
- Verify these points manually:
  - sidebar width and active state
  - top bar placement
  - poster density and aspect ratio
  - typography hierarchy
  - local data/settings group treatments
  - absence of obvious default Material chrome
  - absence of heavy divider lines as grouping crutch
  - glass visible only in top-bar/search contexts
  - gradient visible only in primary emphasis areas

If golden tests are introduced later, use them for shell and page-layout fidelity.

---

## Code Review Checklist

- Does the screen still look like Stitch rather than generic Material?
- Are colors, typography, radii, and spacing taken from shared tokens?
- Did the change preserve desktop density and content-first layout?
- Are shell pieces reusable and kept out of feature-only business logic?
- Did the author avoid one-off visual constants in page files?
- Are labels readable and correctly encoded?
- Did the author preserve the No-Line rule and tonal grouping?
- Is glass usage limited to allowed chrome surfaces?
- Is gradient usage limited to allowed emphasis surfaces?
- Are borders ghosted and low-opacity instead of harsh separators?
- Were analyze/tests run, and was manual preview checked when layout changed?
