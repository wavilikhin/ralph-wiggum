# Ralph Wiggum

```
  ____       _       _       __        ___                       
 |  _ \ __ _| |_ __ | |__    \ \      / (_) __ _ _   _ _   _ _ __ 
 | |_) / _` | | '_ \| '_ \    \ \ /\ / /| |/ _` | | | | | | | '_ \
 |  _ < (_| | | |_) | | | |    \ V  V / | | (_| | |_| | |_| | | | |
 |_| \_\__,_|_| .__/|_| |_|     \_/\_/  |_|\__, |\__,_|\__,_|_| |_|
              |_|                          |___/                   
```

This is a near-vanilla implementation of the [Ralph Wiggum autonomous loop](https://ghuntley.com/ralph/) pattern by Geoffrey Huntley. The core idea: run an AI coding agent in a loop where each iteration gets fresh context, picks exactly one task, implements it, validates it passes all checks, commits, and repeats until done. This produces clean atomic commits and avoids context window bloat.

Built for [OpenCode](https://opencode.ai), but should work with any CLI-based coding agent that can read files and run commands.

**Additions to the original pattern:**
- `npx` initialization that scaffolds everything into a `.ralph/` directory
- Structured logging with timestamps (`.ralph/logs/ralph.log`)
- `--verbose` flag to preserve full agent output per iteration
- Enforces exactly one commit per iteration (fails if zero or multiple)
- Verifies clean working tree after each iteration
- Phases-based `IMPLEMENTATION_PLAN.md` template

---

## What is this?

Ralph Wiggum runs your coding agent in a loop, where each iteration:

1. Starts with **fresh context** (new process, no memory of previous iterations)
2. Picks **exactly one task** from your implementation plan
3. Implements it and runs **validation gates** (lint, test, build)
4. Creates **exactly one commit** (local only, no push)
5. Repeats until all tasks are complete

This approach keeps context focused and produces clean, atomic commits.

## Model Requirements

> **Warning**: Ralph Wiggum requires the latest generation of AI models to work reliably.
> 
> The autonomous loop requires models capable of:
> - Following complex multi-step instructions precisely
> - Making exactly one commit per iteration
> - Running validation commands and fixing failures
> - Updating state files accurately
>
> **Recommended models:**
> - `anthropic/claude-opus-4-20250514`
> - `openai/gpt-5.2`
>
> Using older or less capable models will likely result in failed iterations.

## Prerequisites

- [OpenCode CLI](https://opencode.ai) installed and configured (or another CLI agent)
- Node.js 18+
- Git repository
- **AGENTS.md file in your repo root** (see below)

```bash
# Verify opencode is working
opencode --version

# List available models
opencode models
```

### AGENTS.md Requirement

Ralph Wiggum expects your repository to have a well-configured `AGENTS.md` file at the root. This file tells the AI agent how to validate changes in your project.

Your `AGENTS.md` must include:

1. **Validation commands** - How to run formatting, linting, type checking, and tests
2. **Project structure** - Overview of your codebase layout
3. **Coding standards** - Any conventions the agent should follow

Example minimal `AGENTS.md`:

```markdown
## Validation Commands

Run these commands to validate changes:

1. Format: `npm run format`
2. Lint: `npm run lint`
3. Typecheck: `npm run typecheck`
4. Test: `npm test`

## Project Structure

- `src/` - Source code
- `tests/` - Test files
```

See [OpenCode AGENTS.md documentation](https://opencode.ai/docs/agents-md) for best practices.

## Quick Start

### 1. Initialize in your repo

```bash
cd your-project
npx @wavilikhin/ralph-wiggum init
```

This creates a `.ralph/` directory with:
- `PROMPT.md` - Instructions for the AI agent (has mandatory + customizable sections)
- `IMPLEMENTATION_PLAN.md` - Your task list template
- `run.sh` - The loop runner
- `logs/` - Directory for iteration logs

### 2. Fill in your implementation plan

Edit `.ralph/IMPLEMENTATION_PLAN.md` with your tasks:

```markdown
## Phase 1: Foundation

- [ ] Set up project structure with src/ and tests/ directories
- [ ] Add TypeScript configuration
- [ ] Create initial CI pipeline

## Phase 2: Core Implementation

- [ ] Implement user authentication module
- [ ] Add database connection layer
- [ ] Create REST API endpoints
```

Use the checkbox format (`- [ ]` / `- [x]`) - the agent marks tasks complete as it works.

### 3. Run the loop

```bash
.ralph/run.sh --max-iterations 20 --model anthropic/claude-opus-4-20250514
```

The loop runs until:
- All tasks are complete (agent outputs `<promise>COMPLETE</promise>`)
- Max iterations reached
- You press Ctrl+C

## CLI Options

```bash
.ralph/run.sh [options]

Options:
  --max-iterations N    Maximum iterations (default: 50)
  --model MODEL         Model to use (default: anthropic/claude-opus-4-20250514)
  --variant NAME        Optional variant name for opencode
  --verbose             Enable verbose logging (keeps full opencode output)
  --help                Show help

Environment variables:
  RALPH_MAX_ITERATIONS  Default max iterations
  RALPH_MODEL           Default model
```

## Logging

Ralph Wiggum maintains two types of logs in `.ralph/logs/`:

### Status Log (`.ralph/logs/ralph.log`)

Always written. Contains iteration status with timestamps:

```
[2025-01-19 14:30:15] [ITER] === Iteration 1/20 STARTED ===
[2025-01-19 14:32:47] [ITER] === Iteration 1 FINISHED: SUCCESS (152s) - feat: add user auth module ===
[2025-01-19 14:32:48] [ITER] === Iteration 2/20 STARTED ===
```

Use this to monitor progress:

```bash
# Watch progress in real-time
tail -f .ralph/logs/ralph.log
```

### Verbose Logs (`.ralph/logs/ralph_iter_N.log`)

Full opencode output per iteration. By default, these are deleted after successful iterations. Use `--verbose` to keep them:

```bash
.ralph/run.sh --verbose --max-iterations 10
```

On failure, the iteration log is always preserved for debugging.

## Examples

### Run with Claude Opus 4

```bash
.ralph/run.sh --max-iterations 10 --model anthropic/claude-opus-4-20250514
```

### Run with GPT-5.2

```bash
.ralph/run.sh --max-iterations 10 --model openai/gpt-5.2
```

### Run with environment variables

```bash
export RALPH_MODEL="anthropic/claude-opus-4-20250514"
export RALPH_MAX_ITERATIONS=30
.ralph/run.sh
```

### Dry run (single iteration)

```bash
.ralph/run.sh --max-iterations 1
```

### Debug mode (verbose + single iteration)

```bash
.ralph/run.sh --verbose --max-iterations 1
```

## How It Works

```
                       .ralph/run.sh
                            |
                            v
        +---------------------------------------+
        |         Iteration N                   |
        |  +----------------------------------+ |
        |  | 1. Record git HEAD              | |
        |  | 2. Run: opencode run ...        | |
        |  | 3. Agent reads PROMPT.md        | |
        |  | 4. Agent picks ONE task         | |
        |  | 5. Agent implements + validates | |
        |  | 6. Agent commits (local only)   | |
        |  | 7. Check: exactly 1 commit?     | |
        |  | 8. Check: working tree clean?   | |
        |  | 9. Check: COMPLETE marker?      | |
        |  +----------------------------------+ |
        +---------------------------------------+
                            |
               +------------+------------+
               v                         v
         [COMPLETE]                 [Continue]
          Exit 0                   Iteration N+1
```

Each iteration is a fresh `opencode run` process, so the agent:
- Has no memory of previous iterations
- Must re-read PROMPT.md, AGENTS.md, IMPLEMENTATION_PLAN.md
- Stays focused on one task at a time

## File Structure

After initialization, your repo will have:

```
your-project/
├── .ralph/
│   ├── PROMPT.md              # Agent instructions (edit [CUSTOMIZABLE] sections)
│   ├── IMPLEMENTATION_PLAN.md # Your task list (fill this in)
│   ├── run.sh                 # Loop runner script
│   └── logs/
│       ├── ralph.log          # Iteration status log
│       └── ralph_iter_N.log   # Per-iteration logs (verbose/error only)
├── AGENTS.md                  # Your validation commands (required, you create this)
└── .gitignore                 # Updated to ignore .ralph/logs/
```

### .ralph/PROMPT.md

Contains instructions the agent follows each iteration. Has two types of sections:

- **[MANDATORY] sections**: Core loop mechanics - don't modify these
- **[CUSTOMIZABLE] sections**: Add project-specific context, quality standards

### .ralph/IMPLEMENTATION_PLAN.md

Your task list. Structure it in phases:

```markdown
## Phase 1: Foundation
- [ ] Task 1
- [x] Task 2 (completed)

## Phase 2: Core
- [ ] Task 3

## Discovered Tasks
<!-- Agent adds tasks here as it finds them -->
```

### AGENTS.md (your file, repo root)

Your project's agent configuration. Must exist in repo root before running.

## Safety Features

- **Local only**: Never pushes to remote
- **One commit per iteration**: Enforced by the loop
- **Clean working tree**: Verified after each iteration
- **Max iterations**: Hard stop to prevent runaway loops
- **Validation gates**: All must pass before commit

## Troubleshooting

### "opencode CLI not found"

Install OpenCode:
```bash
npm install -g opencode
```

### "AGENTS.md not found"

Create an `AGENTS.md` file in your repo root with validation commands. See the [AGENTS.md Requirement](#agentsmd-requirement) section.

### "No commit was created"

The agent must create exactly one commit per iteration. Check `.ralph/logs/ralph_iter_N.log` to see what happened. Common causes:
- Validation gates failed
- Agent got stuck on a complex task
- Task was already complete
- Model not capable enough (try a more advanced model)

### "Working tree is not clean"

The agent left uncommitted changes. This usually means validation failed. Check the log and fix manually, then restart.

### Loop never completes

- Check if tasks in `.ralph/IMPLEMENTATION_PLAN.md` are achievable
- Ensure validation commands in AGENTS.md are correct
- Try running with `--verbose --max-iterations 1` to debug a single iteration
- Consider using a more capable model

### Iterations failing consistently

This often indicates the model isn't capable enough for autonomous operation. Try:
- Using `anthropic/claude-opus-4-20250514` or `openai/gpt-5.2`
- Simplifying tasks in IMPLEMENTATION_PLAN.md
- Adding more context to AGENTS.md

## Credits

Based on the [Ralph Wiggum pattern](https://ghuntley.com/ralph/) by Geoffrey Huntley.

## License

MIT
