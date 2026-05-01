<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

This project is managed by Trellis. The working knowledge you need lives under `.trellis/`:

- `.trellis/workflow.md` — development phases, when to create tasks, skill routing
- `.trellis/spec/` — package- and layer-scoped coding guidelines
- `.trellis/workspace/` — per-developer journals and session traces
- `.trellis/tasks/` — active and archived tasks

If a Trellis command is available on your platform, prefer it over manual steps.

If you're using Codex, project-scoped helpers may also live in:
- `.agents/skills/` for reusable Trellis skills
- `.codex/agents/` for optional custom subagents

Managed by Trellis. Edits outside this block are preserved.

<!-- TRELLIS:END -->

# Project Conventions

## PRD language

All newly created task PRDs must be written in Chinese by default.

Scope:
- `.trellis/tasks/*/prd.md`

Rules:
- Write headings, requirements, acceptance criteria, notes, and plans in Chinese.
- Keep code identifiers, command names, library names, protocol names, and external product names in their original language when needed.
- If a tool or template generates an English PRD first, translate it to Chinese before treating it as the project PRD.
