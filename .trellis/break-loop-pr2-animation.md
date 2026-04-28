## Bug Analysis: Page transition "layer glitch" and mistaken performance optimization

### 1. Root Cause Category
- **Category**: E - Implicit Assumption
- **Specific Cause**:
  1. Assumed `go_router CustomTransitionPage.transitionsBuilder` only needs to animate the entering page via `animation`. Did not realize `secondaryAnimation` controls the exiting page's departure, causing the old page to vanish instantly while the new page fades/slides in.
  2. Assumed per-item `AnimationController` in a grid was the performance bottleneck causing "not smooth" feeling. Did not profile; the actual issue was the broken page transition, not the grid entrance animation.

### 2. Why Fixes Failed
1. **First attempt (remove AnimationController)**: Replaced `_StaggeredPosterItem`'s `AnimationController` with `AnimatedOpacity` to "reduce overhead." This preserved fade-in but lost the upward slide component of the staggered entrance. User immediately noticed the missing motion and disliked it. — *Surface fix*: addressed a non-existent performance problem while breaking a loved UX detail.
2. **Second attempt (simplify hover)**: Removed `AnimatedSlide` lift and reduced `BoxShadow` intensity on `PosterCard`, thinking fewer animation layers would help. User reported no improvement in smoothness. — *Mental model*: kept optimizing widget-level animations when the actual issue was at the route transition layer.
3. **Third attempt (fix transition)**: Added `secondaryAnimation` fade-out to both `subtleFade` and `slideIn` transitions. This was the actual fix. — *Correct*: addressed the root cause (old page exit) rather than symptoms.

### 3. Prevention Mechanisms
| Priority | Mechanism | Specific Action | Status |
|----------|-----------|-----------------|--------|
| P0 | Thinking guide | Created `guides/animation-thinking-guide.md` with transition + performance checklist | DONE |
| P0 | Spec update | Added "Interaction Patterns" to `frontend/component-guidelines.md` with `secondaryAnimation` example | DONE |
| P1 | Profile before optimize | Add "profile in release mode" as mandatory step before removing animations | TODO (enforce via PR review) |
| P1 | Bidirectional testing | Test every transition in both push and pop directions | TODO (manual check) |

### 4. Systematic Expansion
- **Similar Issues**: Any future `go_router` transition addition must also verify `secondaryAnimation`. This applies to modal routes, bottom sheets, or any overlay transition.
- **Design Improvement**: Consider wrapping the transition builder in a shared helper that always applies both `animation` and `secondaryAnimation` defaults, making it harder to forget.
- **Process Improvement**: When a user reports "not smooth," ask "which interaction?" (scroll, hover, page transition, initial load) before guessing at the cause. The layer of animation matters.
- **Knowledge Gap**: The difference between `animation` (self enter/exit) and `secondaryAnimation` (covered by another route) in Flutter page transitions is non-obvious and easy to overlook.

### 5. Knowledge Capture
- [x] Updated `.trellis/spec/frontend/component-guidelines.md` — Added "Interaction Patterns" section with transition, staggered grid, and hover patterns
- [x] Created `.trellis/spec/guides/animation-thinking-guide.md` — Pre-animation checklist for future sessions
- [x] Recorded in journal (`trellis:record-session`)
