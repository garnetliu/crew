#!/bin/bash
# crew/lib/status.sh - Status display and monitoring

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/watchdog.sh"

# Show status of all agents
show_status() {
  local config_file="$1"
  local crew_dir=".crew"
  
  header "Crew Status"
  
  if [[ ! -f "$config_file" ]]; then
    log_error "No config found. Run 'crew init' first."
    return 1
  fi
  
  # Get project name
  local project
  project=$(config_get ".project" "$(basename "$PWD")" "$config_file")
  echo "Project: $project"
  echo ""
  
  # Get agent list
  local agents
  agents=$(config_get ".agents[].name" "" "$config_file")
  
  if [[ -z "$agents" ]]; then
    log_warn "No agents configured"
    return 0
  fi
  
  # Print table header
  printf "%-15s %-10s %-10s %-30s\n" "AGENT" "STATUS" "PID" "LAST LOG"
  separator "-" 70
  
  for name in $agents; do
    local status pid_display last_log icon color
    status=$(get_agent_status "$name")
    
    case "$status" in
      running:*)
        pid_display="${status#running:}"
        icon=$(config_get ".agents[] | select(.name == \"$name\") | .icon" "🔵" "$config_file")
        color="$GREEN"
        status_text="running"
        ;;
      stale)
        pid_display="-"
        icon="⚠️"
        color="$YELLOW"
        status_text="stale"
        ;;
      stopped)
        pid_display="-"
        icon="⭕"
        color="$RED"
        status_text="stopped"
        ;;
    esac
    
    # Get last log line
    local log_file="$crew_dir/logs/${name}.log"
    if [[ -f "$log_file" ]]; then
      last_log=$(tail -1 "$log_file" 2>/dev/null | cut -c1-30)
    else
      last_log="-"
    fi
    
    printf "${color}%-15s %-10s %-10s %-30s${NC}\n" "$icon $name" "$status_text" "$pid_display" "$last_log"
  done
  
  echo ""
}

# Real-time monitor (like htop for agents)
monitor_loop() {
  local config_file="$1"
  local refresh="${2:-2}"
  
  trap 'echo ""; return 0' INT TERM

  while true; do
    clear
    show_status "$config_file"
    echo ""
    echo "Press Ctrl+C to exit. Refreshing every ${refresh}s..."
    sleep "$refresh"
  done
}

# Tail logs for an agent
tail_agent_log() {
  local name="$1"
  local lines="${2:-50}"
  local crew_dir=".crew"

  validate_agent_name "$name" || return 1

  local log_file="$crew_dir/logs/${name}.log"

  if [[ ! -f "$log_file" ]]; then
    log_error "No log file for agent: $name"
    return 1
  fi
  
  header "Logs: $name"
  echo "File: $log_file"
  separator "-" 50
  
  tail -f "$log_file"
}

# Show specific agent info
show_agent_info() {
  local name="$1"
  local config_file="$2"
  local crew_dir=".crew"
  
  header "Agent: $name"
  
  # Get config
  local command prompt_file interval timeout icon
  command=$(config_get ".agents[] | select(.name == \"$name\") | .command" "" "$config_file")
  prompt_file=$(config_get ".agents[] | select(.name == \"$name\") | .prompt" "" "$config_file")
  interval=$(config_get ".agents[] | select(.name == \"$name\") | .interval" "10" "$config_file")
  timeout=$(config_get ".agents[] | select(.name == \"$name\") | .timeout" "600" "$config_file")
  icon=$(config_get ".agents[] | select(.name == \"$name\") | .icon" "🔵" "$config_file")
  
  echo "Icon: $icon"
  echo "Command: $command"
  echo "Prompt: $prompt_file"
  echo "Interval: ${interval}s"
  echo "Timeout: ${timeout}s"
  echo ""
  
  # Status
  local status
  status=$(get_agent_status "$name")
  case "$status" in
    running:*)
      echo -e "Status: ${GREEN}Running${NC} (PID: ${status#running:})"
      ;;
    stale)
      echo -e "Status: ${YELLOW}Stale${NC}"
      ;;
    stopped)
      echo -e "Status: ${RED}Stopped${NC}"
      ;;
  esac
  
  # Log info
  local log_file="$crew_dir/logs/${name}.log"
  if [[ -f "$log_file" ]]; then
    local log_size
    log_size=$(du -h "$log_file" | cut -f1)
    echo "Log file: $log_file ($log_size)"
    echo ""
    echo "Last 5 lines:"
    separator "-" 50
    tail -5 "$log_file"
  fi
}
