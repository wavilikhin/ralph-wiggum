#!/usr/bin/env bash
set -euo pipefail

# Ralph Wiggum Loop - Autonomous coding loop
# Each iteration: fresh context, one task, one commit

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Go up one level to get to the repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

#=============================================================================
# Configuration
#=============================================================================

MAX_ITERATIONS="${RALPH_MAX_ITERATIONS:-50}"
MAX_CONSECUTIVE_FAILURES="${RALPH_MAX_CONSECUTIVE_FAILURES:-5}"
AGENT_CMD=""
VERBOSE=false
LIVE=false
STRICT=false
CONSECUTIVE_FAILURES=0

# All ralph files are in .ralph/
RALPH_DIR="$SCRIPT_DIR"
LOGS_DIR="$RALPH_DIR/logs"
LOG_FILE="$LOGS_DIR/ralph.log"
PROMPT_FILE="$RALPH_DIR/PROMPT.md"
PLAN_FILE="$RALPH_DIR/IMPLEMENTATION_PLAN.md"

#=============================================================================
# Colors
#=============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

#=============================================================================
# Logging
#=============================================================================

log_to_file() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
    log_to_file "INFO" "$1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
    log_to_file "OK" "$1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    log_to_file "WARN" "$1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_to_file "ERROR" "$1"
}

log_iteration_start() {
    local iter="$1"
    local max="$2"
    log_to_file "ITER" "=== Iteration $iter/$max STARTED ==="
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  Iteration $iter / $max${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

log_iteration_end() {
    local iter="$1"
    local status="$2"
    local commit_msg="$3"
    local iter_duration="$4"
    local agent_duration="$5"
    log_to_file "ITER" "=== Iteration $iter FINISHED: $status (iter=${iter_duration}s, agent=${agent_duration}s) - $commit_msg ==="
    echo ""
    echo -e "${DIM}Timing: agent=${agent_duration}s, iteration=${iter_duration}s${NC}"
}

#=============================================================================
# Helper Functions
#=============================================================================

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo '  ____       _       _       __        ___                       '
    echo ' |  _ \ __ _| |_ __ | |__    \ \      / (_) __ _ _   _ _   _ _ __ '
    echo ' | |_) / _` | | '"'"'_ \| '"'"'_ \    \ \ /\ / /| |/ _` | | | | | | | '"'"'_ \'
    echo ' |  _ < (_| | | |_) | | | |    \ V  V / | | (_| | |_| | |_| | | | |'
    echo ' |_| \_\__,_|_| .__/|_| |_|     \_/\_/  |_|\__, |\__,_|\__,_|_| |_|'
    echo '              |_|                          |___/                   '
    echo -e "${NC}"
    echo -e "${DIM}  Autonomous coding loop${NC}"
    echo ""
}

print_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --agent-cmd CMD       Command to run each iteration (required)"
    echo "  --max-iterations N    Maximum iterations (default: $MAX_ITERATIONS)"
    echo "  --verbose             Save per-iteration logs (.ralph/logs/ralph_iter_N.log)"
    echo "  --live                Stream agent output to terminal (requires --verbose)"
    echo "  --strict              Exit on any iteration anomaly"
    echo "  --help                Show this help"
    echo ""
    echo "Environment variables:"
    echo "  RALPH_MAX_ITERATIONS  Default max iterations"
    echo ""
    echo "Example:"
    echo "  $0 --agent-cmd 'opencode run --model anthropic/claude-opus-4-20250514'"
    echo "  $0 --agent-cmd 'codex exec --model openai/gpt-5.2 -C .'"
    echo "  $0 --agent-cmd 'pi -p --model openai/gpt-5.2'"
    echo ""
    echo "Logs:"
    echo "  .ralph/logs/ralph.log           Iteration status + timings (always written)"
    echo "  .ralph/logs/ralph_iter_N.log    Full agent output (--verbose only)"
    echo ""
}

check_prerequisites() {
    if [[ -z "$AGENT_CMD" ]]; then
        log_error "--agent-cmd is required. Example:"
        echo "  $0 --agent-cmd 'opencode run --model anthropic/claude-opus-4-20250514'"
        exit 1
    fi

    # Extract first word as the agent binary and check it exists
    local agent_bin
    agent_bin=$(echo "$AGENT_CMD" | awk '{print $1}')
    if ! command -v "$agent_bin" &> /dev/null; then
        log_error "Agent command '$agent_bin' not found in PATH"
        exit 1
    fi

    if [[ ! -f "$PROMPT_FILE" ]]; then
        log_error "PROMPT.md not found at $PROMPT_FILE"
        log_error "Run 'npx ralph-wiggum init' first."
        exit 1
    fi

    if [[ ! -f "$PLAN_FILE" ]]; then
        log_error "IMPLEMENTATION_PLAN.md not found at $PLAN_FILE"
        log_error "Run 'npx ralph-wiggum init' first."
        exit 1
    fi

    if [[ ! -f "$REPO_ROOT/AGENTS.md" ]]; then
        log_warn "AGENTS.md not found in repo root."
        echo ""
        echo "Some agents (like OpenCode) read AGENTS.md for validation commands."
        echo "Consider creating one if your agent supports it."
        echo ""
        echo "See: https://opencode.ai/docs/agents-md"
        echo ""
    fi

    if ! git -C "$REPO_ROOT" rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not in a git repository."
        exit 1
    fi

    if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
        log_warn "Uncommitted changes detected. Consider committing or stashing first."
        echo ""
        git -C "$REPO_ROOT" status --short
        echo ""
        if [[ "$STRICT" == true ]]; then
            log_error "Exiting due to --strict mode"
            exit 1
        fi
    fi
}

#=============================================================================
# Parse Arguments
#=============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --agent-cmd)
            AGENT_CMD="$2"
            shift 2
            ;;
        --max-iterations)
            MAX_ITERATIONS="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --live)
            LIVE=true
            shift
            ;;
        --strict)
            STRICT=true
            shift
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

#=============================================================================
# Main Loop
#=============================================================================

print_banner

mkdir -p "$LOGS_DIR"

# Initialize log file
echo "========================================" >> "$LOG_FILE"
echo "Ralph Wiggum Loop Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
echo "Agent Command: $AGENT_CMD" >> "$LOG_FILE"
echo "Max Iterations: $MAX_ITERATIONS" >> "$LOG_FILE"
echo "Repo: $REPO_ROOT" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

log_info "Configuration:"
echo -e "  ${DIM}Agent command:${NC} $AGENT_CMD"
echo -e "  ${DIM}Max iterations:${NC} $MAX_ITERATIONS"
echo -e "  ${DIM}Verbose:${NC} $VERBOSE"
echo -e "  ${DIM}Live output:${NC} $LIVE"
echo -e "  ${DIM}Strict mode:${NC} $STRICT"
echo -e "  ${DIM}Repo root:${NC} $REPO_ROOT"
echo ""

# Validate --live requires --verbose
if [[ "$LIVE" == true && "$VERBOSE" != true ]]; then
    log_error "--live requires --verbose flag"
    exit 1
fi

check_prerequisites

log_info "Starting autonomous loop..."
log_info "Status log: $LOG_FILE"
echo ""

# Change to repo root for git operations
cd "$REPO_ROOT"

for i in $(seq 1 "$MAX_ITERATIONS"); do
    ITER_START=$(date +%s)
    ITER_LOG_FILE="$LOGS_DIR/ralph_iter_${i}.log"
    LIVE_PREFIX="  ${DIM}[LIVE ${i}/${MAX_ITERATIONS}]${NC} "
    
    log_iteration_start "$i" "$MAX_ITERATIONS"

    # Preflight: verify critical .ralph files exist before starting iteration
    if [[ ! -f "$PROMPT_FILE" ]]; then
        log_error "FATAL: PROMPT.md missing at $PROMPT_FILE"
        log_error "Cannot continue without prompt file. Was it deleted?"
        exit 1
    fi
    if [[ ! -f "$PLAN_FILE" ]]; then
        log_error "FATAL: IMPLEMENTATION_PLAN.md missing at $PLAN_FILE"
        log_error "Cannot continue without plan file. Was it deleted?"
        exit 1
    fi

    BEFORE_HEAD=$(git rev-parse HEAD)
    log_info "HEAD before: ${DIM}${BEFORE_HEAD:0:8}${NC}"

    # Build the agent command from user-provided AGENT_CMD.
    # Ralph stays agent-agnostic: it appends a single instruction prompt as the final argument.
    instruction="Read and follow .ralph/PROMPT.md. Use AGENTS.md for validation commands and .ralph/IMPLEMENTATION_PLAN.md for task selection. Do exactly one task and one local commit."
    full_cmd="$AGENT_CMD $(printf '%q' "$instruction")"

    log_info "Running agent..."
    
    AGENT_START=$(date +%s)
    
    set +e
    if [[ "$LIVE" == true ]]; then
        # Stream to terminal AND write to log file
        # Prefix each agent line so it doesn't visually clash with ralph logs.
        eval "$full_cmd" 2>&1 | while IFS= read -r line; do printf '%b%s\n' "$LIVE_PREFIX" "$line"; done | tee "$ITER_LOG_FILE"
        EXIT_CODE=${PIPESTATUS[0]}
    elif [[ "$VERBOSE" == true ]]; then
        # Write to log file only (no terminal stream)
        eval "$full_cmd" > "$ITER_LOG_FILE" 2>&1
        EXIT_CODE=$?
    else
        # Write to log file only (keep it on errors, delete on success)
        eval "$full_cmd" > "$ITER_LOG_FILE" 2>&1
        EXIT_CODE=$?
    fi
    set -e

    AGENT_END=$(date +%s)
    AGENT_DURATION=$((AGENT_END - AGENT_START))

    ITER_END=$(date +%s)
    ITER_DURATION=$((ITER_END - ITER_START))

    # Postflight: verify critical .ralph files still exist after agent ran
    if [[ ! -f "$PLAN_FILE" ]]; then
        log_error "FATAL: IMPLEMENTATION_PLAN.md was deleted during iteration!"
        log_error "This should not happen. Check log: $ITER_LOG_FILE"
        exit 1
    fi
    if [[ ! -f "$PROMPT_FILE" ]]; then
        log_error "FATAL: PROMPT.md was deleted during iteration!"
        log_error "This should not happen. Check log: $ITER_LOG_FILE"
        exit 1
    fi

    # Protected files: only .ralph/IMPLEMENTATION_PLAN.md may be modified.
    PROTECTED_STATUS=$(git status --porcelain -- .ralph)
    if [[ -n "$PROTECTED_STATUS" ]]; then
        if echo "$PROTECTED_STATUS" | grep -vq 'IMPLEMENTATION_PLAN.md$'; then
            log_error "FATAL: Protected .ralph/ files were modified:"
            echo "$PROTECTED_STATUS" | grep -v 'IMPLEMENTATION_PLAN.md$'
            log_error "Only .ralph/IMPLEMENTATION_PLAN.md may be edited during the loop."
            log_error "Check log: $ITER_LOG_FILE"
            exit 1
        fi
    fi

    if [[ $EXIT_CODE -ne 0 ]]; then
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
        log_error "agent exited with code $EXIT_CODE (failure $CONSECUTIVE_FAILURES/$MAX_CONSECUTIVE_FAILURES)"
        log_error "Check log: $ITER_LOG_FILE"
        log_iteration_end "$i" "FAILED" "agent error" "$ITER_DURATION" "$AGENT_DURATION"
        
        if [[ $CONSECUTIVE_FAILURES -ge $MAX_CONSECUTIVE_FAILURES ]]; then
            log_error "FATAL: $CONSECUTIVE_FAILURES consecutive failures reached. Stopping loop."
            log_error "Review recent logs in $LOGS_DIR to diagnose the issue."
            log_to_file "ERROR" "=== LOOP STOPPED: $CONSECUTIVE_FAILURES CONSECUTIVE FAILURES ==="
            exit 1
        fi
        
        if [[ "$STRICT" == true ]]; then
            exit 1
        fi
        log_warn "Continuing despite error (use --strict to exit on errors)"
        echo ""
        continue
    fi

    # Reset consecutive failure counter on success
    CONSECUTIVE_FAILURES=0

    AFTER_HEAD=$(git rev-parse HEAD)
    log_info "HEAD after: ${DIM}${AFTER_HEAD:0:8}${NC}"

    if [[ "$BEFORE_HEAD" == "$AFTER_HEAD" ]]; then
        log_warn "No commit was created in this iteration."
        log_iteration_end "$i" "WARN" "no commit created" "$ITER_DURATION" "$AGENT_DURATION"
        if [[ "$STRICT" == true ]]; then
            log_error "Exiting due to --strict mode"
            exit 1
        fi
        echo ""
        continue
    fi

    COMMIT_COUNT=$(git rev-list --count "$BEFORE_HEAD".."$AFTER_HEAD")
    if [[ "$COMMIT_COUNT" -ne 1 ]]; then
        log_warn "Expected 1 commit, but $COMMIT_COUNT were created."
        log_iteration_end "$i" "WARN" "$COMMIT_COUNT commits" "$ITER_DURATION" "$AGENT_DURATION"
        if [[ "$STRICT" == true ]]; then
            log_error "Exiting due to --strict mode"
            exit 1
        fi
        # Still show the commits that were made
        COMMIT_MSG=$(git log -1 --format='%s')
        log_info "Latest commit: $COMMIT_MSG"
        echo ""
        continue
    fi

    if [[ -n "$(git status --porcelain)" ]]; then
        log_warn "Working tree is not clean after iteration."
        echo ""
        git status --short
        log_iteration_end "$i" "WARN" "dirty working tree" "$ITER_DURATION" "$AGENT_DURATION"
        if [[ "$STRICT" == true ]]; then
            log_error "Exiting due to --strict mode"
            exit 1
        fi
        echo ""
        continue
    fi

    COMMIT_MSG=$(git log -1 --format='%s')
    log_success "Commit created: $COMMIT_MSG"
    
    if grep -q '<promise>COMPLETE</promise>' "$ITER_LOG_FILE"; then
        log_iteration_end "$i" "COMPLETE" "$COMMIT_MSG" "$ITER_DURATION" "$AGENT_DURATION"
        if [[ "$VERBOSE" != true ]]; then
            rm -f "$ITER_LOG_FILE"
        fi
        echo ""
        log_success "All tasks complete!"
        echo ""
        echo -e "${GREEN}${BOLD}Loop finished successfully after $i iteration(s)${NC}"
        log_to_file "INFO" "=== LOOP COMPLETED SUCCESSFULLY ==="
        exit 0
    fi

    log_iteration_end "$i" "SUCCESS" "$COMMIT_MSG" "$ITER_DURATION" "$AGENT_DURATION"
    
    if [[ "$VERBOSE" != true ]]; then
        rm -f "$ITER_LOG_FILE"
    fi
    
    echo ""
done

echo ""
log_warn "Max iterations ($MAX_ITERATIONS) reached without completion."
log_warn "Check IMPLEMENTATION_PLAN.md for remaining tasks."
log_to_file "WARN" "=== LOOP STOPPED: MAX ITERATIONS REACHED ==="
exit 1
