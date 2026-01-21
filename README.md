# Ralph Wiggum

[![npm version](https://img.shields.io/npm/v/@wavilikhin/ralph-wiggum.svg)](https://www.npmjs.com/package/@wavilikhin/ralph-wiggum)
[![npm publish](https://github.com/wavilikhin/ralph-wiggum/actions/workflows/publish.yml/badge.svg)](https://github.com/wavilikhin/ralph-wiggum/actions/workflows/publish.yml)

```
  ____       _       _       __        ___                       
 |  _ \ __ _| |_ __ | |__    \ \      / (_) __ _ _   _ _   _ _ __ 
 | |_) / _` | | '_ \| '_ \    \ \ /\ / /| |/ _` | | | | | | | '_ \
 |  _ < (_| | | |_) | | | |    \ V  V / | | (_| | |_| | |_| | | | |
 |_| \_\__,_|_| .__/|_| |_|     \_/\_/  |_|\__, |\__,_|\__,_|_| |_|
              |_|                          |___/                   
```

Ralph Wiggum is a tiny wrapper around the “autonomous loop” pattern: run an AI coding agent repeatedly, but keep each iteration small and strict.

Origin: the [Ralph Wiggum autonomous loop](https://ghuntley.com/ralph/) pattern by Geoffrey Huntley.

Each iteration:
- starts with fresh context (new process)
- completes exactly one plan item
- runs your repo’s validation commands
- creates exactly one local git commit

This keeps context focused and your history clean.

## Install

No global install needed:

```bash
npx @wavilikhin/ralph-wiggum init
```

(Inside an existing git repo.)

## Quick start

1) Ensure you have prerequisites:
- Node.js 18+
- `opencode` installed and configured (or another CLI agent)
- a repo-root `AGENTS.md` that lists your validation commands

2) Scaffold `.ralph/`:

```bash
npx @wavilikhin/ralph-wiggum init
```

3) Fill in tasks:
- Edit `.ralph/IMPLEMENTATION_PLAN.md`
- Use checkboxes (`- [ ]`, `- [x]`)

4) Run the loop:

```bash
.ralph/run.sh --max-iterations 20 --model anthropic/claude-opus-4-20250514
```

The loop stops when either:
- all tasks are checked off and the agent outputs `<promise>COMPLETE</promise>`
- `--max-iterations` is reached
- you press Ctrl+C

## Flags

`ralph-wiggum init` scaffolds files. The loop itself is controlled via `.ralph/run.sh`.

Any additional flags are forwarded to `opencode run`.

```bash
.ralph/run.sh [options]

Options:
  --max-iterations N    Maximum iterations before stopping (default: 50)
  --model MODEL         Model to use (default: anthropic/claude-opus-4-20250514)
  --variant NAME        Optional variant name passed to opencode
  --verbose             Keep per-iteration logs (.ralph/logs/ralph_iter_N.log)
  --live                Stream opencode output (requires --verbose)
  --help                Show help

Environment variables:
  RALPH_MAX_ITERATIONS           Default max iterations
  RALPH_MAX_CONSECUTIVE_FAILURES Max consecutive failures before stopping (default: 5)
  RALPH_MODEL                    Default model
```

## What gets created

`init` creates a `.ralph/` directory:
- `.ralph/PROMPT.md` – instructions the agent reads every iteration
- `.ralph/IMPLEMENTATION_PLAN.md` – your checklist of tasks
- `.ralph/run.sh` – the loop runner
- `.ralph/logs/` – log directory (ignored via `.gitignore`)

## Logs

- `.ralph/logs/ralph.log` is always written (timestamps + iteration status).
- `.ralph/logs/ralph_iter_N.log` is kept only with `--verbose` (or on failures).

Watch progress:

```bash
tail -f .ralph/logs/ralph.log
```

## Safety

- Never pushes: commits are local only.
- Enforces one commit per iteration.
- Requires a clean working tree after each iteration.
- **Protected `.ralph/` directory**: The agent can only edit `.ralph/IMPLEMENTATION_PLAN.md`. All other `.ralph/` files are protected from modification/deletion via OpenCode permissions.
- **Circuit breaker**: Loop stops after 5 consecutive failures (configurable via `RALPH_MAX_CONSECUTIVE_FAILURES`).
- **Fail-fast on missing files**: If `.ralph/PROMPT.md` or `.ralph/IMPLEMENTATION_PLAN.md` is missing, the loop exits immediately.

### Permissions

Ralph Wiggum injects OpenCode permissions to:
1. Allow `external_directory` to prevent blocking prompts during autonomous execution
2. Protect `.ralph/` files from deletion/modification (only `IMPLEMENTATION_PLAN.md` is editable)
3. Block dangerous bash commands targeting `.ralph/` (`rm`, `mv`, `git rm`, `git mv`)

These protections are always active. If you need to override them (not recommended), set `OPENCODE_CONFIG_CONTENT` manually:

```bash
OPENCODE_CONFIG_CONTENT='{"permission":"allow"}' .ralph/run.sh
```

See [OpenCode Permissions](https://opencode.ai/docs/permissions) for details.

<details>
<summary><strong>AI agent appendix (full detail)</strong></summary>

### Model requirements

This loop is strict and works best with high-end models that can follow multistep instructions reliably:
- `anthropic/claude-opus-4-20250514`
- `openai/gpt-5.2`

### `AGENTS.md` (repo root) is required

Ralph Wiggum expects a repo-root `AGENTS.md` that tells the agent how to validate changes.

At minimum, include:
- formatting command
- lint command
- typecheck command (if applicable)
- test command

Example (minimal):

```markdown
## Validation Commands
1. Format: `npm run format`
2. Lint: `npm run lint`
3. Typecheck: `npm run typecheck`
4. Test: `npm test`
```

OpenCode docs: https://opencode.ai/docs/agents-md

### What happens each iteration

- A fresh `opencode run` process starts (no memory).
- The agent reads (at least) `.ralph/PROMPT.md`, `.ralph/IMPLEMENTATION_PLAN.md`, and `AGENTS.md`.
- The agent must pick exactly one unchecked task, implement it, run all validation gates, update the plan, and make exactly one commit.
- When every task is complete, the agent must output exactly `<promise>COMPLETE</promise>`.

### Templates

Scaffolded from:
- `templates/PROMPT.md`
- `templates/IMPLEMENTATION_PLAN.md`

</details>

## Credits

Based on the [Ralph Wiggum pattern](https://ghuntley.com/ralph/) by Geoffrey Huntley.

## License

MIT
