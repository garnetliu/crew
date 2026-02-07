#!/bin/bash
# crew/lib/watchdog.sh - Health monitoring and auto-restart

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Default values
DEFAULT_CHECK_INTERVAL=30
DEFAULT_TIMEOUT=600
DEFAULT_RESTART_DELAY=5

# Export per-agent env vars from config
# Usage: export_agent_env <name> <config_file>
export_agent_env() {
  local name="$1"
  local config_file="$2"
  [[ -z "$config_file" || ! -f "$config_file" ]] && return 0

  local env_keys
  env_keys=$(config_get ".agents[] | select(.name == \"$name\") | .env | keys | .[]" "" "$config_file")
  [[ -z "$env_keys" || "$env_keys" == "null" ]] && return 0

  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    local value
    value=$(config_get ".agents[] | select(.name == \"$name\") | .env.$key" "" "$config_file")
    if [[ -n "$value" && "$value" != "null" ]]; then
      export "$key=$value"
    fi
  done <<< "$env_keys"
}

# Start an agent in background with monitoring
start_agent() {
  local name="$1"
  local command="$2"
  local prompt_file="$3"
  local interval="${4:-$DEFAULT_RESTART_DELAY}"
  local working_dir="${5:-$PWD}"
  local config_file="${6:-}"
  local crew_dir=".crew"

  validate_agent_name "$name" || return 1

  ensure_dir "$crew_dir/logs"
  ensure_dir "$crew_dir/run"

  local log_file="$crew_dir/logs/${name}.log"
  local pid_file="$crew_dir/run/${name}.pid"

  # Check if already running
  if is_agent_running "$name"; then
    log_warn "[$name] Already running (PID: $(cat "$pid_file"))"
    return 1
  fi

  log_info "[$name] Starting (restart delay: ${interval}s)..."

  # Validate prompt file
  if [[ ! -f "$prompt_file" ]]; then
    log_error "[$name] Prompt file not found: $prompt_file"
    return 1
  fi

  # Start agent in background
  (
    # Export per-agent env vars (only affects this subshell)
    export_agent_env "$name" "$config_file"

    cd "$working_dir" || exit 1
    while true; do
      echo "[$name] Starting at $(timestamp)" >> "$log_file"
      # Run command as array (no eval - prevents arbitrary code execution from config)
      local cmd_array
      read -ra cmd_array <<< "$command"
      "${cmd_array[@]}" < "$prompt_file" >> "$log_file" 2>&1
      local exit_code=$?

      echo "[$name] Exited with code $exit_code at $(timestamp)" >> "$log_file"

      # Check if we should restart
      if [[ ! -f "$pid_file" ]]; then
        echo "[$name] PID file removed, stopping." >> "$log_file"
        break
      fi

      # Wait before restart
      echo "[$name] Restarting in ${interval}s..." >> "$log_file"
      sleep "$interval"
    done
  ) &

  local pid=$!
  echo "$pid" > "$pid_file"

  log_ok "[$name] Started (PID: $pid)"
  log_info "[$name] Log: $log_file"
}

# Stop an agent gracefully
stop_agent() {
  local name="$1"
  local crew_dir=".crew"
  local pid_file="$crew_dir/run/${name}.pid"
  
  if [[ ! -f "$pid_file" ]]; then
    log_warn "[$name] Not running (no PID file)"
    return 0
  fi
  
  local pid
  pid=$(cat "$pid_file")
  
  log_info "[$name] Stopping (PID: $pid)..."
  
  # Remove PID file first (signals the loop to stop)
  rm -f "$pid_file"
  
  # Send SIGTERM for graceful shutdown
  if kill -TERM "$pid" 2>/dev/null; then
    # Wait up to 10 seconds for graceful exit
    local wait_count=0
    while kill -0 "$pid" 2>/dev/null && [[ $wait_count -lt 10 ]]; do
      sleep 1
      wait_count=$((wait_count + 1))
    done
    
    # Force kill if still alive
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null
      log_warn "[$name] Force killed"
    else
      log_ok "[$name] Stopped gracefully"
    fi
  else
    log_warn "[$name] Process not found (already stopped)"
  fi
}

# Check if agent is running
is_agent_running() {
  local name="$1"
  local crew_dir=".crew"
  local pid_file="$crew_dir/run/${name}.pid"
  
  if [[ ! -f "$pid_file" ]]; then
    return 1
  fi
  
  local pid
  pid=$(cat "$pid_file")
  
  kill -0 "$pid" 2>/dev/null
}

# Get agent status
get_agent_status() {
  local name="$1"
  local crew_dir=".crew"
  local pid_file="$crew_dir/run/${name}.pid"
  local log_file="$crew_dir/logs/${name}.log"
  
  if is_agent_running "$name"; then
    local pid
    pid=$(cat "$pid_file")
    echo "running:$pid"
  elif [[ -f "$pid_file" ]]; then
    echo "stale"  # PID file exists but process dead
  else
    echo "stopped"
  fi
}

# Restart an agent
restart_agent() {
  local name="$1"
  local config_file="$2"
  
  stop_agent "$name"
  sleep 1
  
  # Get agent config and restart
  local command prompt_file interval
  command=$(config_get ".agents[] | select(.name == \"$name\") | .command" "" "$config_file")
  prompt_file=$(config_get ".agents[] | select(.name == \"$name\") | .prompt" "" "$config_file")
  interval=$(config_get ".agents[] | select(.name == \"$name\") | .interval" "$DEFAULT_RESTART_DELAY" "$config_file")
  
  if [[ -n "$command" && -n "$prompt_file" ]]; then
    start_agent "$name" "$command" ".crew/$prompt_file" "$interval" "$PWD" "$config_file" || true
  else
    log_error "[$name] Cannot restart: missing config"
  fi
}

# Start all agents from config
start_all_agents() {
  local config_file="$1"
  
  if [[ ! -f "$config_file" ]]; then
    log_error "Config file not found: $config_file"
    return 1
  fi
  
  # Get list of agent names
  local agents
  agents=$(config_get ".agents[].name" "" "$config_file")
  
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    validate_agent_name "$name" || continue
    local command prompt_file interval
    command=$(config_get ".agents[] | select(.name == \"$name\") | .command" "" "$config_file")
    prompt_file=$(config_get ".agents[] | select(.name == \"$name\") | .prompt" "" "$config_file")
    interval=$(config_get ".agents[] | select(.name == \"$name\") | .interval" "$DEFAULT_RESTART_DELAY" "$config_file")
    
    if [[ -n "$command" && -n "$prompt_file" ]]; then
      start_agent "$name" "$command" ".crew/$prompt_file" "$interval" "$PWD" "$config_file" || true
    else
      log_warn "[$name] Skipping: missing command or prompt"
    fi
  done <<< "$agents"
}

# Stop all agents
stop_all_agents() {
  local crew_dir=".crew"
  
  if [[ ! -d "$crew_dir/run" ]]; then
    log_info "No agents running"
    return 0
  fi
  
  for pid_file in "$crew_dir/run"/*.pid; do
    if [[ -f "$pid_file" ]]; then
      local name
      name=$(basename "$pid_file" .pid)
      stop_agent "$name"
    fi
  done
}

# Watchdog loop - monitor and restart agents
watchdog_loop() {
  local config_file="$1"
  local check_interval="${2:-$DEFAULT_CHECK_INTERVAL}"
  
  log_info "Watchdog started (interval: ${check_interval}s)"

  trap 'log_info "Watchdog stopping..."; return 0' INT TERM

  while true; do
    sleep "$check_interval"
    
    # Check each agent
    local agents
    agents=$(config_get ".agents[].name" "" "$config_file")
    
    for name in $agents; do
      local status
      status=$(get_agent_status "$name")
      
      case "$status" in
        running:*)
          # All good
          ;;
        stale)
          log_warn "[$name] Stale PID file, cleaning up..."
          rm -f ".crew/run/${name}.pid"
          restart_agent "$name" "$config_file"
          ;;
        stopped)
          log_warn "[$name] Not running, starting..."
          local command prompt_file
          command=$(config_get ".agents[] | select(.name == \"$name\") | .command" "" "$config_file")
          prompt_file=$(config_get ".agents[] | select(.name == \"$name\") | .prompt" "" "$config_file")
          start_agent "$name" "$command" "$prompt_file"
          ;;
      esac
    done
  done
}
