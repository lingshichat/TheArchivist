<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

Use the `/trellis:start` command when starting a new session to:
- Initialize your developer identity
- Understand current project context
- Read relevant guidelines

Use `@/.trellis/` to learn:
- Development workflow (`workflow.md`)
- Project structure guidelines (`spec/`)
- Developer workspace (`workspace/`)

If you're using Codex, project-scoped helpers may also live in:
- `.agents/skills/` for reusable Trellis skills
- `.codex/agents/` for optional custom subagents

Keep this managed block so 'trellis update' can refresh the instructions.

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
