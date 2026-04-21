# Task & Spec Governance

> Where durable decisions belong across root tasks, phase tasks, child tasks, and code-spec documents.

---

## Overview

This project uses parent tasks to capture strategy and shared contracts, child
tasks to capture bounded implementation work, and `.trellis/spec/` to preserve
reusable implementation rules.

The goal is to keep the task tree clean:

- no extra sibling task just to restate long-lived architecture rules
- no child task becoming the accidental source of truth for future work
- no architecture drift hidden inside one-off PRDs

---

## Scenario: Capturing a durable decision

### 1. Scope / Trigger

Use this governance contract when the work introduces or changes any of:

- shared signatures used by multiple child tasks
- local-first or sync source-of-truth rules
- provider placement / dependency direction
- external integration boundaries
- parent/child task decomposition
- reusable backend / frontend code-spec rules

### 2. Signatures

Relevant artifacts:

```text
.trellis/tasks/<root-or-phase>/prd.md
.trellis/tasks/<child>/prd.md
.trellis/spec/architecture/*.md
.trellis/spec/backend/*.md
.trellis/spec/frontend/*.md
.trellis/spec/guides/*.md
```

Relevant task commands:

```bash
python ./.trellis/scripts/task.py create "<title>" --parent <task>
python ./.trellis/scripts/task.py add-subtask <parent> <child>
python ./.trellis/scripts/task.py start <task>
```

### 3. Contracts

#### Root task PRD

Owns:

- product direction
- phase split
- milestone ordering
- project-wide architecture rules that affect multiple phases

#### Phase parent PRD

Owns:

- shared contracts for all child work packages in that phase
- stable interface boundaries between child tasks
- phase-level scope, out-of-scope, and acceptance

#### Child task PRD

Owns:

- bounded implementation slice
- local acceptance criteria
- task-specific research notes

Child tasks must not become the only place where shared phase contracts live.

#### `.trellis/spec/`

Owns:

- executable implementation rules
- signatures, payload shapes, error behavior, and test points
- cross-layer architecture contracts that future tasks must reuse

#### `guides/`

Owns:

- thinking prompts and checklists only
- guides point to specs; they do not duplicate full code-spec content

### 4. Validation & Error Matrix

| Decision type | Required landing zone | Do not do this |
|---------------|-----------------------|----------------|
| Project-wide sync or architecture rule | root PRD + `spec/architecture/` | hide it in one child PRD |
| Phase-wide shared interface | phase parent PRD + relevant spec | duplicate inconsistent variants across children |
| One child’s local acceptance detail | child PRD | promote it to a new top-level task without a new deliverable |
| Reusable coding rule | `spec/backend/` or `spec/frontend/` | leave it only in implementation code comments |
| Pre-implementation reminder | `spec/guides/` | turn guides into rule-heavy duplicates of specs |
| Pure spec cleanup without a new product slice | update existing parent task + spec | create a new sibling feature task |

### 5. Good / Base / Bad Cases

#### Good

- Bangumi phase parent PRD owns the shared sync boundary
- architecture spec owns local-first and dependency-direction rules
- WP PRDs focus on their own deliverables

#### Base

- a child PRD repeats a parent rule for convenience, but the parent/spec remains
  the canonical source of truth

#### Bad

- a new “brainstorm” or sibling task is created only to restate architecture
- future work must reopen an old child PRD to find a phase-wide contract

### 6. Tests Required

- Task-tree review:
  - no new sibling task exists unless there is a new user-visible or
    independently executable deliverable
- Spec review:
  - durable contracts changed in code are reflected in the right spec files
- Parent/child review:
  - shared phase rules exist in parent PRD
  - child PRDs keep bounded implementation scope

### 7. Wrong vs Correct

#### Wrong

```text
Root task
 ├── Phase 2 parent
 │    ├── WP1
 │    ├── WP2
 │    └── WP3
 └── "spec-cleanup-task"
```

Why it is wrong:

- the extra task does not represent a new product slice
- architecture ownership becomes ambiguous

#### Correct

```text
Root task
 ├── Phase 2 parent  -> owns shared Bangumi contracts
 │    ├── WP1        -> API client slice
 │    ├── WP2        -> search/add slice
 │    └── WP3        -> auth/sync slice
 └── spec/architecture + backend/frontend -> durable implementation rules
```

Why it is correct:

- the task tree stays product-oriented
- stable rules are preserved in reusable specs
- future child tasks inherit one clear source of truth
