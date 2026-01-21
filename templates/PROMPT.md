# Ralph Wiggum - Single Iteration Prompt

> This file instructs the AI agent on what to do in ONE iteration of the autonomous loop.
> Sections marked [MANDATORY] must not be modified. Sections marked [CUSTOMIZABLE] can be adjusted.

---

## [MANDATORY] Orientation Phase

Before doing anything:

1. **Read `AGENTS.md`** - contains validation commands (lint, test, build) you MUST run
2. **Read `IMPLEMENTATION_PLAN.md`** - contains the task list with priorities and completion status
3. **Search the codebase** before assuming anything is missing - use grep/glob to verify

---

## [MANDATORY] Protected Files

**The `.ralph/` directory is protected.** These rules are enforced:

- **NEVER** delete, move, or rename any file in `.ralph/`
- **NEVER** modify `.ralph/PROMPT.md` or `.ralph/ralph-loop.sh`
- You may **ONLY** edit `.ralph/IMPLEMENTATION_PLAN.md` to:
  - Mark tasks complete: `- [ ]` → `- [x]`
  - Add discovered follow-up tasks
  - Update notes or learnings

Violating these rules will cause the loop to fail.

---

## [MANDATORY] Task Selection

Pick **exactly ONE** task from `IMPLEMENTATION_PLAN.md`:

- Choose the highest-priority incomplete item (marked `- [ ]`)
- If multiple items have the same priority, pick the one that unblocks others
- Do NOT work on multiple tasks in a single iteration

---

## [MANDATORY] Implementation + Validation

1. **Implement** the selected task completely
2. **Run ALL validation gates** from `AGENTS.md`:
   - Formatting
   - Linting  
   - Type checking
   - Tests
3. **Fix any failures** before proceeding - do not leave broken code
4. Iterate until all gates pass

---

## [MANDATORY] State Persistence

After implementation is validated:

1. **Update `IMPLEMENTATION_PLAN.md`**:
   - Mark the completed task: `- [ ]` → `- [x]`
   - Add any discovered follow-up tasks to the appropriate phase
   - Update any notes or learnings

---

## [MANDATORY] Commit (Local Only)

Create exactly ONE commit for this iteration:

```bash
git add -A
git commit -m "<type>: <concise description of what was done>"
```

Rules:
- **Do NOT push** - local commits only
- **Exactly ONE commit** per iteration
- Use conventional commit format: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`

---

## [MANDATORY] Completion Check

**Only if ALL of the following are true:**
- Every task in `IMPLEMENTATION_PLAN.md` is marked `[x]`
- All validation gates pass
- No pending follow-up tasks remain

**Then output exactly:**

```
<promise>COMPLETE</promise>
```

**Otherwise, do NOT output this marker.** The loop will continue with a fresh context.

---

## [CUSTOMIZABLE] Project-Specific Context

<!-- Add any project-specific instructions here -->
<!-- Examples: -->
<!-- - Preferred coding patterns -->
<!-- - Architecture decisions to follow -->
<!-- - Files/directories to avoid modifying -->
<!-- - Special considerations for this codebase -->

---

## [CUSTOMIZABLE] Quality Standards

<!-- Define your quality bar here -->
<!-- Examples: -->
<!-- - Test coverage requirements -->
<!-- - Documentation requirements -->
<!-- - Performance considerations -->
<!-- - Security considerations -->

---

## Summary

Each iteration you must:
1. Orient (read AGENTS.md, IMPLEMENTATION_PLAN.md)
2. Pick ONE task
3. Implement + validate (all gates must pass)
4. Update IMPLEMENTATION_PLAN.md
5. Make exactly ONE local commit
6. Output `<promise>COMPLETE</promise>` only when truly done
