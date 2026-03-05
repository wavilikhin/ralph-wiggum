import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path, { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const ralphRepoRoot = resolve(__dirname, "..");
const ralphCliPath = join(ralphRepoRoot, "src", "cli.js");

function run(bin, args, opts = {}) {
  return spawnSync(bin, args, { encoding: "utf8", ...opts });
}

function runOk(bin, args, opts = {}) {
  const res = run(bin, args, opts);
  if (res.status !== 0) {
    throw new Error(
      [
        `command failed: ${bin} ${args.join(" ")}`,
        `status: ${String(res.status)}`,
        res.stdout ? `stdout:\n${res.stdout}` : "",
        res.stderr ? `stderr:\n${res.stderr}` : "",
      ]
        .filter(Boolean)
        .join("\n"),
    );
  }
  return res;
}

function git(cwd, args) {
  return runOk("git", args, { cwd });
}

function gitOut(cwd, args) {
  const res = runOk("git", args, { cwd });
  return res.stdout.trim();
}

function writeStub(binDir, name) {
  const filePath = join(binDir, name);
  const script = `#!/usr/bin/env bash
set -euo pipefail

log_dir="\${RALPH_STUB_LOG_DIR:?RALPH_STUB_LOG_DIR missing}"
mkdir -p "$log_dir"

printf '%s\\n' "$@" > "$log_dir/${name}.argv"

git -c commit.gpgsign=false commit --no-verify --allow-empty -m "test: ${name} iteration" >/dev/null

echo "<promise>COMPLETE</promise>"
`;
  writeFileSync(filePath, script, "utf8");
  chmodSync(filePath, 0o755);
}

function setupTempRepo(t) {
  const tmpRoot = os.tmpdir();
  const repoDir = join(tmpRoot, `ralph tmp ${Date.now()} ${Math.random().toString(16).slice(2)}`);
  mkdirSync(repoDir, { recursive: true });
  t.after(() => rmSync(repoDir, { recursive: true, force: true }));

  git(repoDir, ["init"]);
  git(repoDir, ["config", "user.email", "test@example.com"]);
  git(repoDir, ["config", "user.name", "Ralph Test"]);
  git(repoDir, ["config", "commit.gpgsign", "false"]);

  writeFileSync(join(repoDir, "README.md"), "test\n", "utf8");
  git(repoDir, ["add", "README.md"]);
  git(repoDir, ["commit", "--no-verify", "-m", "chore: init"]);

  runOk(process.execPath, [ralphCliPath, "init"], { cwd: repoDir });
  git(repoDir, ["add", "-A"]);
  git(repoDir, ["commit", "--no-verify", "-m", "chore: add ralph"]);

  const stubBin = join(repoDir, ".ralph", "logs", "stub-bin");
  const stubLogs = join(repoDir, ".ralph", "logs", "stub-logs");
  mkdirSync(stubBin);
  mkdirSync(stubLogs);
  for (const name of ["pi", "codex", "opencode", "claude"]) writeStub(stubBin, name);

  return { repoDir, stubBin, stubLogs };
}

const instructionStart = "Read and follow .ralph/PROMPT.md.";

test("ralph loop runs with common agent CLIs (stubbed)", async (t) => {
  const cases = [
    {
      name: "pi",
      agentCmd: "pi -p --model openai/gpt-5.2 --thinking minimal @.ralph/PROMPT.md @.ralph/IMPLEMENTATION_PLAN.md",
      mustContainArgs: ["-p", "--model", "openai/gpt-5.2", "--thinking", "minimal", "@.ralph/PROMPT.md", "@.ralph/IMPLEMENTATION_PLAN.md"],
    },
    {
      name: "codex",
      agentCmd: "codex exec --model openai/gpt-5.2 -C . --skip-git-repo-check",
      mustContainArgs: ["exec", "--model", "openai/gpt-5.2", "-C", ".", "--skip-git-repo-check"],
    },
    {
      name: "opencode",
      agentCmd: "opencode run --model anthropic/claude-opus-4-20250514 --variant high -f .ralph/PROMPT.md -f .ralph/IMPLEMENTATION_PLAN.md",
      mustContainArgs: ["run", "--model", "anthropic/claude-opus-4-20250514", "--variant", "high", "-f", ".ralph/PROMPT.md", "-f", ".ralph/IMPLEMENTATION_PLAN.md"],
    },
    {
      name: "claude",
      agentCmd: "claude -p --model sonnet --effort low",
      mustContainArgs: ["-p", "--model", "sonnet", "--effort", "low"],
    },
  ];

  for (const c of cases) {
    await t.test(c.name, () => {
      const { repoDir, stubBin, stubLogs } = setupTempRepo(t);
      const env = {
        ...process.env,
        PATH: `${stubBin}${path.delimiter}${process.env.PATH ?? ""}`,
        RALPH_STUB_LOG_DIR: stubLogs,
      };

      const beforeHead = gitOut(repoDir, ["rev-parse", "HEAD"]);

      const res = run("bash", [".ralph/run.sh", "--max-iterations", "3", "--agent-cmd", c.agentCmd], { cwd: repoDir, env });
      assert.equal(res.status, 0, `loop exited non-zero (stdout/stderr in error)\nstdout:\n${res.stdout}\nstderr:\n${res.stderr}`);

      const afterHead = gitOut(repoDir, ["rev-parse", "HEAD"]);
      assert.notEqual(beforeHead, afterHead, "expected a new commit");
      assert.equal(gitOut(repoDir, ["rev-list", "--count", `${beforeHead}..${afterHead}`]), "1", "expected exactly 1 commit");

      const argvPath = join(stubLogs, `${c.name}.argv`);
      const argv = readFileSync(argvPath, "utf8").trimEnd().split("\n");

      for (const token of c.mustContainArgs) assert(argv.includes(token), `missing arg token: ${token}`);
      assert(!argv.includes("--file"), "ralph must not inject --file");

      const lastArg = argv.at(-1);
      assert(lastArg?.startsWith(instructionStart), "expected appended instruction prompt as last arg");
      assert(lastArg.includes(".ralph/IMPLEMENTATION_PLAN.md"), "expected plan path in instruction prompt");
    });
  }
});
