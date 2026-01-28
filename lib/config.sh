#!/bin/bash
# crew/lib/config.sh - Configuration parsing

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Default config file names
CREW_CONFIG_NAME="crew.yaml"
DESIGN_CONFIG_NAME="design.yaml"

# Find config file in current or parent directories
find_config() {
  local config_name="${1:-$CREW_CONFIG_NAME}"
  local dir="$PWD"
  
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.crew/$config_name" ]]; then
      echo "$dir/.crew/$config_name"
      return 0
    elif [[ -f "$dir/.design/$config_name" ]]; then
      echo "$dir/.design/$config_name"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  
  return 1
}

# Parse YAML config using yq or fallback
parse_yaml() {
  local query="$1"
  local config_file="$2"
  
  if ! [[ -f "$config_file" ]]; then
    log_error "Config file not found: $config_file"
    return 1
  fi
  
  if command_exists yq; then
    yq eval "$query" "$config_file"
  elif command_exists python3; then
    # Fallback to Python with PyYAML or ruamel.yaml
    python3 << EOF
import sys
try:
    import yaml
except ImportError:
    print("Error: Install PyYAML (pip install pyyaml)", file=sys.stderr)
    sys.exit(1)

with open("$config_file") as f:
    config = yaml.safe_load(f)

# Simple query parsing (supports .key.subkey format)
query = "$query".lstrip('.')
result = config
for key in query.split('.'):
    if key and result is not None:
        if isinstance(result, dict):
            result = result.get(key)
        elif isinstance(result, list) and key.isdigit():
            result = result[int(key)] if int(key) < len(result) else None
        else:
            result = None

if result is not None:
    if isinstance(result, (dict, list)):
        print(yaml.dump(result, default_flow_style=False).strip())
    else:
        print(result)
EOF
  else
    log_error "Install yq (brew install yq) or python3 with pyyaml"
    return 1
  fi
}

# Get config value with default
config_get() {
  local query="$1"
  local default="$2"
  local config_file="$3"
  
  local value
  value=$(parse_yaml "$query" "$config_file" 2>/dev/null)
  
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "$default"
  else
    echo "$value"
  fi
}

# Get agent type (with CREW_AGENT env override)
get_agent_type() {
  local config_file="$1"
  
  # Environment variable takes precedence
  if [[ -n "$CREW_AGENT" ]]; then
    echo "$CREW_AGENT"
    return
  fi
  
  # Then config file
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    local agent
    agent=$(config_get ".agent" "" "$config_file")
    if [[ -n "$agent" ]]; then
      echo "$agent"
      return
    fi
  fi
  
  # Default
  echo "claude"
}

# Validate config file
validate_config() {
  local config_file="$1"
  
  if ! [[ -f "$config_file" ]]; then
    log_error "Config file not found: $config_file"
    return 1
  fi
  
  # Check if parseable
  if ! parse_yaml "." "$config_file" > /dev/null 2>&1; then
    log_error "Invalid YAML syntax in: $config_file"
    return 1
  fi
  
  log_ok "Config valid: $config_file"
  return 0
}
