# Ralph Wiggum

A tiny autonomous coding loop:

- picks one task from a plan
- runs your AI agent with fresh context
- expects exactly one commit per iteration
- repeats until tasks are done or max iterations reached

Package: `@wavilikhin/ralph-wiggum`

---

## Install

```bash
npm i -D @wavilikhin/ralph-wiggum
```

Or run without installing:

```bash
npx @wavilikhin/ralph-wiggum init
```

---

## Quick start

From repo root:

**1. Initialize Ralph files:**

```bash
npx @wavilikhin/ralph-wiggum init
```

**2. Edit your plan:**

```bash
.ralph/IMPLEMENTATION_PLAN.md
```

**3. (Optional) Customize the prompt:**

```bash
.ralph/PROMPT.md
```

**4. (Optional) Add AGENTS.md to help your AI agent:**

Create an `AGENTS.md` in your repo root with validation commands (lint, test, build). Some agents read this to know how to validate changes.

**5. Run the loop:**

```bash
.ralph/run.sh --agent-cmd "opencode run --model anthropic/claude-opus-4-20250514 -f .ralph/PROMPT.md -f .ralph/IMPLEMENTATION_PLAN.md"
```

---

## Loop options

```bash
.ralph/run.sh [options]

Options:
  --agent-cmd CMD       Command to run each iteration (required)
  --max-iterations N    Maximum iterations (default: 50)
  --verbose             Save per-iteration logs
  --live                Stream agent output (requires --verbose)
  --strict              Exit on any iteration anomaly
  --help                Show help
```

Environment variables:

- `RALPH_MAX_ITERATIONS` — default max iterations
- `RALPH_MAX_CONSECUTIVE_FAILURES` — stop after N failures (default: 5)

---

## What gets created

`ralph-wiggum init` creates:

```text
.ralph/
  run.sh
  PROMPT.md
  IMPLEMENTATION_PLAN.md
  logs/.gitkeep
```

And updates `.gitignore` to ignore `.ralph/logs/`.

---

## Agent compatibility

Ralph works with any CLI agent that runs non-interactively and accepts the prompt as the final CLI argument.
Put model/agent params into `--agent-cmd` (Ralph does not rewrite your flags). Examples:

```bash
# OpenCode
.ralph/run.sh --agent-cmd "opencode run --model anthropic/claude-opus-4-20250514 -f .ralph/PROMPT.md -f .ralph/IMPLEMENTATION_PLAN.md"

# Codex
.ralph/run.sh --agent-cmd "codex exec --model openai/gpt-5.2 -C ."

# Claude Code
.ralph/run.sh --agent-cmd "claude -p --model sonnet"

# Pi
.ralph/run.sh --agent-cmd "pi -p --model openai/gpt-5.2 @.ralph/PROMPT.md @.ralph/IMPLEMENTATION_PLAN.md"
```

Some agents (like OpenCode) look for an `AGENTS.md` file with validation commands. This helps them run lint/test/build checks automatically. Create one if your agent supports it.

---

## License

MIT
