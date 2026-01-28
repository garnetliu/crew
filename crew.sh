#!/bin/bash
# crew - Multi-agent parallel orchestration
#
# Usage:
#   crew init            Create .crew/ with template config
#   crew start [AGENT..] Start all or specific agents
#   crew stop [AGENT..]  Stop all or specific agents
#   crew restart [AGENT] Restart agent(s)
#   crew status          Show agent status
#   crew monitor         Real-time dashboard
#   crew logs AGENT      Tail agent logs
#   crew validate        Check config syntax

set -e

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/watchdog.sh"
source "$SCRIPT_DIR/lib/status.sh"

VERSION="0.1.0"
CREW_DIR=".crew"
CONFIG_FILE="$CREW_DIR/crew.yaml"

usage() {
  cat << EOF
${BOLD}crew${NC} - Multi-agent parallel orchestration

${BOLD}USAGE${NC}
  crew <command> [options]

${BOLD}COMMANDS${NC}
  init                 Create .crew/ with template config
  start [AGENT...]     Start all or specific agents
  stop [AGENT...]      Stop all or specific agents
  restart [AGENT...]   Restart agent(s)
  status               Show agent status
  monitor              Real-time dashboard
  logs <AGENT>         Tail agent logs
  validate             Check config syntax
  help                 Show this help

${BOLD}OPTIONS${NC}
  --check-interval N   Health check interval in seconds (default: 30)
  --no-watchdog        Start agents without watchdog

${BOLD}EXAMPLES${NC}
  # Initialize in a project
  crew init

  # Start all agents
  crew start

  # Start specific agents
  crew start QA DEV

  # Monitor in real-time
  crew monitor

  # View logs
  crew logs QA

${BOLD}FILES${NC}
  .crew/
  ├── crew.yaml         Config file
  ├── prompts/          Agent prompts
  ├── logs/             Agent logs
  └── run/              PID files

${BOLD}VERSION${NC}
  $VERSION
EOF
}

# Initialize crew in current directory
crew_init() {
  header "Initializing Crew"
  
  if [[ -d "$CREW_DIR" ]]; then
    if ! confirm ".$CREW_DIR already exists. Overwrite config?"; then
      return 0
    fi
  fi
  
  ensure_dir "$CREW_DIR"
  ensure_dir "$CREW_DIR/prompts"
  ensure_dir "$CREW_DIR/logs"
  ensure_dir "$CREW_DIR/run"
  
  # Create default config
  cat > "$CONFIG_FILE" << 'EOF'
# Crew Configuration
project: my-project
log_dir: .crew/logs
check_interval: 30

agents:
  - name: QA
    icon: 🔴
    command: claude --dangerously-skip-permissions
    prompt: prompts/qa.md
    interval: 10
    timeout: 600

  - name: DEV
    icon: 🔵
    command: claude --dangerously-skip-permissions
    prompt: prompts/dev.md
    interval: 10
    timeout: 600

  - name: JANITOR
    icon: 🟢
    command: claude --dangerously-skip-permissions
    prompt: prompts/janitor.md
    interval: 10
    timeout: 600
EOF
  log_ok "Created $CONFIG_FILE"

  # Copy default prompts from crew home
  local crew_home
  crew_home=$(get_crew_home)

  for role in qa dev janitor; do
    if [[ -f "$crew_home/prompts/crew/${role}.md" ]]; then
      cp "$crew_home/prompts/crew/${role}.md" "$CREW_DIR/prompts/"
      log_ok "Copied prompts/${role}.md"
    else
      log_warn "Default prompt not found: prompts/crew/${role}.md"
    fi
  done
  
  echo ""
  log_info "Crew initialized!"
  log_info "Edit $CONFIG_FILE to configure agents"
  log_info "Run 'crew start' to begin"
}

# Start agents
crew_start() {
  local agents=("$@")
  
  if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "No config found. Run 'crew init' first."
    return 1
  fi
  
  header "Starting Agents"
  
  if [[ ${#agents[@]} -eq 0 ]]; then
    # Start all
    start_all_agents "$CONFIG_FILE"
  else
    # Start specific agents
    for name in "${agents[@]}"; do
      local command prompt_file
      command=$(config_get ".agents[] | select(.name == \"$name\") | .command" "" "$CONFIG_FILE")
      prompt_file=$(config_get ".agents[] | select(.name == \"$name\") | .prompt" "" "$CONFIG_FILE")
      
      if [[ -z "$command" ]]; then
        log_error "[$name] Not found in config"
        continue
      fi
      
      start_agent "$name" "$command" "$CREW_DIR/$prompt_file"
    done
  fi
}

# Stop agents
crew_stop() {
  local agents=("$@")
  
  header "Stopping Agents"
  
  if [[ ${#agents[@]} -eq 0 ]]; then
    stop_all_agents
  else
    for name in "${agents[@]}"; do
      stop_agent "$name"
    done
  fi
}

# Restart agents
crew_restart() {
  local agents=("$@")
  
  header "Restarting Agents"
  
  if [[ ${#agents[@]} -eq 0 ]]; then
    stop_all_agents
    sleep 2
    start_all_agents "$CONFIG_FILE"
  else
    for name in "${agents[@]}"; do
      restart_agent "$name" "$CONFIG_FILE"
    done
  fi
}

# Show status
crew_status() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "No config found. Run 'crew init' first."
    return 1
  fi
  
  show_status "$CONFIG_FILE"
}

# Monitor mode
crew_monitor() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "No config found. Run 'crew init' first."
    return 1
  fi
  
  monitor_loop "$CONFIG_FILE"
}

# Tail logs
crew_logs() {
  local name="$1"
  
  if [[ -z "$name" ]]; then
    log_error "Usage: crew logs <AGENT>"
    return 1
  fi
  
  tail_agent_log "$name"
}

# Validate config
crew_validate() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "No config found."
    return 1
  fi
  
  validate_config "$CONFIG_FILE"
}

# Main
main() {
  local cmd="${1:-help}"
  shift 2>/dev/null || true
  
  case "$cmd" in
    init)
      crew_init
      ;;
    start)
      crew_start "$@"
      ;;
    stop)
      crew_stop "$@"
      ;;
    restart)
      crew_restart "$@"
      ;;
    status)
      crew_status
      ;;
    monitor)
      crew_monitor
      ;;
    logs)
      crew_logs "$@"
      ;;
    validate)
      crew_validate
      ;;
    help|--help|-h)
      usage
      ;;
    version|--version|-v)
      echo "crew $VERSION"
      ;;
    *)
      log_error "Unknown command: $cmd"
      echo ""
      usage
      exit 1
      ;;
  esac
}

main "$@"
