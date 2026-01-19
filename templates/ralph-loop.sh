#!/usr/bin/env bash
set -euo pipefail

# Ralph Wiggum Loop - Autonomous coding loop for OpenCode
# Each iteration: fresh context, one task, one commit

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Go up one level to get to the repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

#=============================================================================
# Configuration
#=============================================================================

MAX_ITERATIONS="${RALPH_MAX_ITERATIONS:-50}"
MODEL="${RALPH_MODEL:-anthropic/claude-opus-4-20250514}"
VARIANT=""
VERBOSE=false

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
    local duration="$4"
    log_to_file "ITER" "=== Iteration $iter FINISHED: $status (${duration}s) - $commit_msg ==="
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
    echo -e "${DIM}  Autonomous coding loop for OpenCode${NC}"
    echo ""
}

print_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --max-iterations N    Maximum iterations (default: $MAX_ITERATIONS)"
    echo "  --model MODEL         Model to use (default: $MODEL)"
    echo "  --variant NAME        Variant name for opencode"
    echo "  --verbose             Enable verbose logging (full opencode output)"
    echo "  --help                Show this help"
    echo ""
    echo "Environment variables:"
    echo "  RALPH_MAX_ITERATIONS  Default max iterations"
    echo "  RALPH_MODEL           Default model"
    echo ""
    echo "Logs:"
    echo "  .ralph/logs/ralph.log           Iteration status (always written)"
    echo "  .ralph/logs/ralph_iter_N.log    Full opencode output (verbose mode or on error)"
    echo ""
    echo "Example:"
    echo "  $0 --max-iterations 10 --model anthropic/claude-opus-4-20250514"
}

check_prerequisites() {
    if ! command -v opencode &> /dev/null; then
        log_error "opencode CLI not found. Install it first:"
        echo "  npm install -g opencode"
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
        log_error "AGENTS.md not found in repo root."
        echo ""
        echo "Ralph Wiggum requires an AGENTS.md file with your validation commands."
        echo "This file tells the agent how to lint, test, and build your project."
        echo ""
        echo "Create AGENTS.md with at minimum:"
        echo "  - Formatting command"
        echo "  - Linting command"
        echo "  - Type checking command (if applicable)"
        echo "  - Test command"
        echo ""
        echo "See: https://opencode.ai/docs/agents-md"
        exit 1
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
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

#=============================================================================
# Parse Arguments
#=============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --max-iterations)
            MAX_ITERATIONS="$2"
            shift 2
            ;;
        --model)
            MODEL="$2"
            shift 2
            ;;
        --variant)
            VARIANT="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

#=============================================================================
# Main Loop
#=============================================================================

print_banner

log_info "Configuration:"
echo -e "  ${DIM}Max iterations:${NC} $MAX_ITERATIONS"
echo -e "  ${DIM}Model:${NC} $MODEL"
echo -e "  ${DIM}Verbose:${NC} $VERBOSE"
echo -e "  ${DIM}Repo root:${NC} $REPO_ROOT"
[[ -n "$VARIANT" ]] && echo -e "  ${DIM}Variant:${NC} $VARIANT"
echo ""

check_prerequisites

mkdir -p "$LOGS_DIR"

# Initialize log file
echo "========================================" >> "$LOG_FILE"
echo "Ralph Wiggum Loop Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
echo "Model: $MODEL" >> "$LOG_FILE"
echo "Max Iterations: $MAX_ITERATIONS" >> "$LOG_FILE"
echo "Repo: $REPO_ROOT" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

log_info "Starting autonomous loop..."
log_info "Status log: $LOG_FILE"
echo ""

# Change to repo root for git operations
cd "$REPO_ROOT"

for i in $(seq 1 "$MAX_ITERATIONS"); do
    ITER_START=$(date +%s)
    ITER_LOG_FILE="$LOGS_DIR/ralph_iter_${i}.log"
    
    log_iteration_start "$i" "$MAX_ITERATIONS"

    BEFORE_HEAD=$(git rev-parse HEAD)
    log_info "HEAD before: ${DIM}${BEFORE_HEAD:0:8}${NC}"

    OPENCODE_CMD=(
        opencode run
        --model "$MODEL"
        --file "$PROMPT_FILE"
        --file "$PLAN_FILE"
    )
    
    if [[ -n "$VARIANT" ]]; then
        OPENCODE_CMD+=(--variant "$VARIANT")
    fi
    
    OPENCODE_CMD+=("Follow the attached PROMPT.md. Use AGENTS.md for validation commands and IMPLEMENTATION_PLAN.md for task selection. Do exactly one task and one commit.")

    log_info "Running opencode..."
    
    set +e
    if [[ "$VERBOSE" == true ]]; then
        OUTPUT=$("${OPENCODE_CMD[@]}" 2>&1 | tee "$ITER_LOG_FILE")
    else
        OUTPUT=$("${OPENCODE_CMD[@]}" 2>&1)
        echo "$OUTPUT" > "$ITER_LOG_FILE"
    fi
    EXIT_CODE=$?
    set -e

    ITER_END=$(date +%s)
    ITER_DURATION=$((ITER_END - ITER_START))

    if [[ $EXIT_CODE -ne 0 ]]; then
        log_error "opencode exited with code $EXIT_CODE"
        log_error "Check log: $ITER_LOG_FILE"
        log_iteration_end "$i" "FAILED" "opencode error" "$ITER_DURATION"
        exit 1
    fi

    if echo "$OUTPUT" | grep -q '<promise>COMPLETE</promise>'; then
        echo ""
        log_success "All tasks complete!"
        echo ""
        echo -e "${GREEN}${BOLD}Loop finished successfully after $i iteration(s)${NC}"
        log_iteration_end "$i" "COMPLETE" "all tasks done" "$ITER_DURATION"
        log_to_file "INFO" "=== LOOP COMPLETED SUCCESSFULLY ==="
        exit 0
    fi

    AFTER_HEAD=$(git rev-parse HEAD)
    log_info "HEAD after: ${DIM}${AFTER_HEAD:0:8}${NC}"

    if [[ "$BEFORE_HEAD" == "$AFTER_HEAD" ]]; then
        log_error "No commit was created in this iteration!"
        log_error "The agent must create exactly one commit per iteration."
        log_error "Check log: $ITER_LOG_FILE"
        log_iteration_end "$i" "FAILED" "no commit created" "$ITER_DURATION"
        exit 1
    fi

    COMMIT_COUNT=$(git rev-list --count "$BEFORE_HEAD".."$AFTER_HEAD")
    if [[ "$COMMIT_COUNT" -ne 1 ]]; then
        log_error "Expected 1 commit, but $COMMIT_COUNT were created!"
        log_iteration_end "$i" "FAILED" "multiple commits" "$ITER_DURATION"
        exit 1
    fi

    if [[ -n "$(git status --porcelain)" ]]; then
        log_error "Working tree is not clean after iteration!"
        echo ""
        git status --short
        log_iteration_end "$i" "FAILED" "dirty working tree" "$ITER_DURATION"
        exit 1
    fi

    COMMIT_MSG=$(git log -1 --format='%s')
    log_success "Commit created: $COMMIT_MSG"
    log_iteration_end "$i" "SUCCESS" "$COMMIT_MSG" "$ITER_DURATION"
    
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
