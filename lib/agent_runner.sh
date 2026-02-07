#!/bin/bash
# crew/lib/agent_runner.sh - Unified agent interface
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Agent runner - unified interface for multiple CLI agents
# Usage: agent_runner <agent_type> <prompt_file> [--inject FILE...]
agent_runner() {
  local agent_type="$1"
  local prompt_file="$2"
  shift 2
  
  local inject_files=()
  local working_dir="$PWD"
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --inject)
        shift
        inject_files+=("$1")
        ;;
      --cwd)
        shift
        working_dir="$1"
        ;;
      *)
        log_warn "Unknown argument: $1"
        ;;
    esac
    shift
  done
  
  # Validate prompt file
  if [[ ! -f "$prompt_file" ]]; then
    log_error "Prompt file not found: $prompt_file"
    return 1
  fi
  
  # Build the full prompt with injected context
  local full_prompt
  full_prompt=$(build_prompt "$prompt_file" "${inject_files[@]+"${inject_files[@]}"}")
  
  # Run the appropriate agent
  log_debug "Running agent: $agent_type"
  log_debug "Prompt file: $prompt_file"
  log_debug "Inject files: ${inject_files[*]:-}"
  
  case "$agent_type" in
    claude)
      run_claude "$full_prompt" "$working_dir"
      ;;
    opencode)
      run_opencode "$full_prompt" "$working_dir"
      ;;
    gemini)
      run_gemini "$full_prompt" "$working_dir"
      ;;
    *)
      log_error "Unknown agent type: $agent_type"
      log_info "Supported: claude, opencode, gemini"
      return 1
      ;;
  esac
}

# Build prompt with injected files
build_prompt() {
  local prompt_file="$1"
  shift
  local inject_files=("$@")
  
  local prompt=""
  
  # Add injected context first
  for file in "${inject_files[@]}"; do
    if [[ -f "$file" ]]; then
      local filename
      filename=$(basename "$file")
      prompt+="<context file=\"$filename\">"$'\n'
      prompt+=$(cat "$file")
      prompt+=$'\n'"</context>"$'\n\n'
    fi
  done
  
  # Add main prompt
  prompt+=$(cat "$prompt_file")
  
  echo "$prompt"
}

# Run Claude CLI
run_claude() {
  local prompt="$1"
  local working_dir="$2"
  
  if ! command_exists claude; then
    log_error "Claude CLI not found. Install: npm install -g @anthropic-ai/claude-code"
    return 1
  fi
  
  (cd "$working_dir" && echo "$prompt" | claude --dangerously-skip-permissions -p -)
}

# Run OpenCode CLI
run_opencode() {
  local prompt="$1"
  local working_dir="$2"
  
  if ! command_exists opencode; then
    log_error "OpenCode CLI not found."
    return 1
  fi
  
  (cd "$working_dir" && echo "$prompt" | opencode --prompt -)
}

# Run Gemini CLI
run_gemini() {
  local prompt="$1"
  local working_dir="$2"
  
  if ! command_exists gemini; then
    log_error "Gemini CLI not found."
    return 1
  fi
  
  (cd "$working_dir" && echo "$prompt" | gemini --prompt -)
}

# Check if agent is available
check_agent() {
  local agent_type="$1"
  
  case "$agent_type" in
    claude)
      command_exists claude
      ;;
    opencode)
      command_exists opencode
      ;;
    gemini)
      command_exists gemini
      ;;
    *)
      return 1
      ;;
  esac
}

# List available agents
list_agents() {
  echo "Available agents:"
  for agent in claude opencode gemini; do
    if check_agent "$agent"; then
      echo -e "  ${GREEN}✓${NC} $agent"
    else
      echo -e "  ${RED}✗${NC} $agent (not installed)"
    fi
  done
}
