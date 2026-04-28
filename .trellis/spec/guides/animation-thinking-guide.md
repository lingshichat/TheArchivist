# Animation Thinking Guide

> Checklist before adding or modifying animations in The Archivist.

---

## Page Transitions

- [ ] Did I handle **both** `animation` (new page enter) and `secondaryAnimation` (old page exit)?
- [ ] Did I test the transition in **both directions** (A→B and B→A)?
- [ ] Does the transition duration feel symmetric, or does one direction feel jarring?
- [ ] For `go_router` `CustomTransitionPage`: verify `transitionsBuilder` uses both parameters.

**Gotcha**: Ignoring `secondaryAnimation` makes the old page disappear instantly while the new page animates in. This creates a "layer glitch" that feels unpolished.

**Pattern**: Use `fadeOut` on `secondaryAnimation` for sibling pages, and `slideIn + fadeIn` / `fadeOut` for detail overlays.

---

## Grid/Card Entrance Animations

- [ ] Does the grid have many items (20+)? Consider `TweenAnimationBuilder` over per-item `AnimationController`.
- [ ] Is the delay per item bounded? Clamp total stagger duration to avoid long empty states.
- [ ] Did I verify the animation still works after hot reload?

**Gotcha**: Creating `SingleTickerProviderStateMixin` + `AnimationController` per grid item scales poorly. `TweenAnimationBuilder` achieves the same visual result without manual ticker management.

---

## Hover Interactions

- [ ] Is the hover feedback visible enough with a single cue? Combine at least two of: lift, shadow, surface color shift.
- [ ] Is the duration under 250ms? Long hover transitions feel sluggish on desktop.
- [ ] Does the shadow intensity match the surface darkness? Dark themes need stronger shadows to read as elevation.

**Gotcha**: A 2px lift (`Offset(0, -0.015)`) without shadow or color change is nearly invisible. Always pair motion with surface/shadow reinforcement.

---

## Performance Before Optimization

- [ ] Did I profile in **release mode** before blaming animations for jank?
- [ ] Is the jank reproducible, or only on first run (shader compilation)?
- [ ] Did I check if the issue is transition logic (missing `secondaryAnimation`) rather than widget overhead?

**Rule**: Do not remove user-visible animation effects as a "performance fix" without profiling data. The real bottleneck is usually elsewhere.

---

## Related Specs

- `frontend/component-guidelines.md` — Interaction Patterns section for concrete code examples
