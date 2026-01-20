#!/usr/bin/env node

import { fileURLToPath } from "url";
import { dirname, join } from "path";
import { readFileSync, writeFileSync, existsSync, mkdirSync, copyFileSync, chmodSync } from "fs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const TEMPLATES_DIR = join(__dirname, "..", "templates");

const RED = "\x1b[31m";
const CYAN = "\x1b[36m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const BOLD = "\x1b[1m";
const RESET = "\x1b[0m";
const DIM = "\x1b[2m";

function printBanner() {
  console.log(`
${CYAN}${BOLD}  ____       _       _       __        ___                       
 |  _ \\ __ _| |_ __ | |__    \\ \\      / (_) __ _ _   _ _   _ _ __ 
 | |_) / _\` | | '_ \\| '_ \\    \\ \\ /\\ / /| |/ _\` | | | | | | | '_ \\
 |  _ < (_| | | |_) | | | |    \\ V  V / | | (_| | |_| | |_| | | | |
 |_| \\_\\__,_|_| .__/|_| |_|     \\_/\\_/  |_|\\__, |\\__,_|\\__,_|_| |_|
              |_|                          |___/                   ${RESET}
${DIM}  Autonomous coding loop for OpenCode${RESET}
`);
}

function printUsage() {
  console.log(`${BOLD}Usage:${RESET}
  npx ralph-wiggum init    Scaffold ralph-wiggum files in .ralph/ directory
  npx ralph-wiggum help    Show this help message
`);
}

function checkAgentsMd(targetDir) {
  const agentsPath = join(targetDir, "AGENTS.md");
  return existsSync(agentsPath);
}

function printNextSteps(hasAgentsMd) {
  console.log(`
${GREEN}${BOLD}Files created successfully!${RESET}

${YELLOW}${BOLD}Next steps:${RESET}
`);

  if (!hasAgentsMd) {
    console.log(`${RED}${BOLD}[REQUIRED]${RESET} Create AGENTS.md in your repo root:
   ${DIM}This file must contain your validation commands (lint, test, build).${RESET}
   ${DIM}The agent reads this file to know how to validate changes.${RESET}
   ${DIM}See: https://opencode.ai/docs/agents-md${RESET}
`);
  } else {
    console.log(`${GREEN}[OK]${RESET} AGENTS.md found in repo root
`);
  }

  console.log(`${BOLD}1.${RESET} Fill in your implementation plan:
   ${DIM}Edit ${CYAN}.ralph/IMPLEMENTATION_PLAN.md${RESET}${DIM} with your tasks using the checkbox format${RESET}

${BOLD}2.${RESET} (Optional) Customize the prompt:
   ${DIM}Edit ${CYAN}.ralph/PROMPT.md${RESET}${DIM} - mandatory sections are marked, customize the rest${RESET}

${BOLD}3.${RESET} Run the loop:
   ${CYAN}.ralph/run.sh --max-iterations 10 --model anthropic/claude-opus-4-20250514${RESET}

${YELLOW}${BOLD}Important:${RESET} This tool works best with the latest generation models.
${DIM}Recommended: anthropic/claude-opus-4-20250514 or openai/gpt-5.2${RESET}

${YELLOW}Available loop options:${RESET}
  --max-iterations N    Maximum iterations before stopping (default: 50)
  --model provider/m    Model to use (default: anthropic/claude-opus-4-20250514)
  --variant name        Optional variant name passed to opencode
  --verbose             Save per-iteration logs (.ralph/logs/ralph_iter_N.log)
  --live                Stream opencode output to terminal (requires --verbose)

${DIM}Logs are written to ${CYAN}.ralph/logs/ralph.log${RESET}${DIM} (iteration status + timings)${RESET}
${DIM}Verbose logs: ${CYAN}.ralph/logs/ralph_iter_N.log${RESET}${DIM} (full output per iteration, --verbose only)${RESET}

${DIM}The loop stops automatically when all tasks are complete (<promise>COMPLETE</promise>)${RESET}
`);
}

function copyTemplate(templateName, destPath, options = {}) {
  const templatePath = join(TEMPLATES_DIR, templateName);
  
  if (!existsSync(templatePath)) {
    console.error(`Template not found: ${templateName}`);
    process.exit(1);
  }

  if (existsSync(destPath) && !options.overwrite) {
    console.log(`${YELLOW}Skipping${RESET} ${destPath} (already exists)`);
    return false;
  }

  const destDir = dirname(destPath);
  if (!existsSync(destDir)) {
    mkdirSync(destDir, { recursive: true });
  }

  copyFileSync(templatePath, destPath);
  
  if (destPath.endsWith(".sh")) {
    chmodSync(destPath, "755");
  }
  
  console.log(`${GREEN}Created${RESET} ${destPath}`);
  return true;
}

function ensureGitignore(targetDir) {
  const gitignorePath = join(targetDir, ".gitignore");
  const logsEntry = ".ralph/logs/";
  
  if (existsSync(gitignorePath)) {
    const content = readFileSync(gitignorePath, "utf-8");
    if (!content.includes(logsEntry)) {
      writeFileSync(gitignorePath, content.trimEnd() + "\n" + logsEntry + "\n");
      console.log(`${GREEN}Updated${RESET} .gitignore (added .ralph/logs/)`);
    } else {
      console.log(`${YELLOW}Skipping${RESET} .gitignore (.ralph/logs/ already ignored)`);
    }
  } else {
    writeFileSync(gitignorePath, logsEntry + "\n");
    console.log(`${GREEN}Created${RESET} .gitignore`);
  }
}

function initCommand(targetDir) {
  const ralphDir = join(targetDir, ".ralph");
  
  console.log(`${BOLD}Initializing ralph-wiggum in ${ralphDir}${RESET}\n`);

  // Create .ralph directory
  if (!existsSync(ralphDir)) {
    mkdirSync(ralphDir, { recursive: true });
  }

  // Copy templates into .ralph/
  copyTemplate("PROMPT.md", join(ralphDir, "PROMPT.md"));
  copyTemplate("IMPLEMENTATION_PLAN.md", join(ralphDir, "IMPLEMENTATION_PLAN.md"));
  copyTemplate("ralph-loop.sh", join(ralphDir, "run.sh"));

  // Create logs directory inside .ralph/
  const logsDir = join(ralphDir, "logs");
  if (!existsSync(logsDir)) {
    mkdirSync(logsDir, { recursive: true });
    writeFileSync(join(logsDir, ".gitkeep"), "");
    console.log(`${GREEN}Created${RESET} .ralph/logs/.gitkeep`);
  }

  // Update .gitignore to ignore .ralph/logs/
  ensureGitignore(targetDir);

  const hasAgentsMd = checkAgentsMd(targetDir);
  printNextSteps(hasAgentsMd);
}

const args = process.argv.slice(2);
const command = args[0];

printBanner();

switch (command) {
  case "init":
    initCommand(process.cwd());
    break;
  case "help":
  case "--help":
  case "-h":
  case undefined:
    printUsage();
    break;
  default:
    console.error(`Unknown command: ${command}\n`);
    printUsage();
    process.exit(1);
}
