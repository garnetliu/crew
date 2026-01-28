#!/bin/bash
# crew/lib/orchestrator.sh - Cross-review orchestration engine

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/agent_runner.sh"

# Exit codes
EXIT_PASS=0
EXIT_MAX_ITER=1
EXIT_STALE=2
EXIT_CONFLICT=3

# Cross-review loop
# Usage: cross_review_loop [max_iterations]
cross_review_loop() {
  local design_dir=".design"
  local config_file="$design_dir/design.yaml"
  
  # Get config values
  local max_iter
  max_iter=$(config_get ".max_iterations" "5" "$config_file")
  local stale_threshold
  stale_threshold=$(config_get ".termination.stale_threshold" "2" "$config_file")
  local conflict_threshold
  conflict_threshold=$(config_get ".termination.conflict_threshold" "3" "$config_file")
  local agent_type
  agent_type=$(get_agent_type "$config_file")
  
  # Get prompt paths
  local writer_prompt
  writer_prompt=$(config_get ".prompts.plan_writer" "prompts/plan_writer.md" "$config_file")
  local reviewer_prompt
  reviewer_prompt=$(config_get ".prompts.reviewer" "prompts/reviewer.md" "$config_file")
  
  # Resolve prompt paths (check local .design first, then crew home)
  writer_prompt=$(resolve_prompt_path "$writer_prompt" "$design_dir")
  reviewer_prompt=$(resolve_prompt_path "$reviewer_prompt" "$design_dir")
  
  # State tracking
  local iter=0
  local stale_count=0
  local prev_plan_hash=""
  local issue_history=""
  
  header "Cross-Review Loop"
  log_info "Agent: $agent_type"
  log_info "Max iterations: $max_iter"
  log_info "Stale threshold: $stale_threshold"
  log_info "Conflict threshold: $conflict_threshold"
  echo ""
  
  # Ensure history directory exists
  ensure_dir "$design_dir/history"
  
  while [ "$iter" -lt "$max_iter" ]; do
    iter=$((iter + 1))
    separator "=" 50
    echo -e "${BOLD}Iteration $iter / $max_iter${NC}"
    separator "=" 50
    
    # ─────────────────────────────────────────────
    # Stage 1: Plan Writer
    # ─────────────────────────────────────────────
    log_info "Running Plan Writer..."
    
    local inject_args=()
    [[ -f "$design_dir/idea.txt" ]] && inject_args+=(--inject "$design_dir/idea.txt")
    [[ -f "$design_dir/plan.md" ]] && inject_args+=(--inject "$design_dir/plan.md")
    [[ -f "$design_dir/review.md" ]] && inject_args+=(--inject "$design_dir/review.md")
    
    if ! agent_runner "$agent_type" "$writer_prompt" "${inject_args[@]}" --cwd "$PWD"; then
      log_error "Plan Writer failed"
      return 1
    fi
    
    # Check for stale (no substantive changes)
    local curr_hash
    curr_hash=$(file_hash "$design_dir/plan.md")
    
    if [[ "$curr_hash" == "$prev_plan_hash" ]]; then
      stale_count=$((stale_count + 1))
      log_warn "No changes detected (stale count: $stale_count/$stale_threshold)"
      
      if [[ "$stale_count" -ge "$stale_threshold" ]]; then
        log_warn "Plan stale for $stale_threshold iterations. Stopping."
        log_info "This may indicate the plan is as good as it can get, or Writer is stuck."
        return $EXIT_STALE
      fi
    else
      stale_count=0
      prev_plan_hash="$curr_hash"
    fi
    
    # Save to history
    cp "$design_dir/plan.md" "$design_dir/history/plan_v${iter}.md"
    log_ok "Plan saved to history/plan_v${iter}.md"
    
    # ─────────────────────────────────────────────
    # Stage 2: Reviewer
    # ─────────────────────────────────────────────
    log_info "Running Reviewer..."
    
    if ! agent_runner "$agent_type" "$reviewer_prompt" \
        --inject "$design_dir/plan.md" \
        --cwd "$PWD"; then
      log_error "Reviewer failed"
      return 1
    fi
    
    # Save review to history
    cp "$design_dir/review.md" "$design_dir/history/review_v${iter}.md"
    log_ok "Review saved to history/review_v${iter}.md"
    
    # ─────────────────────────────────────────────
    # Check Decision
    # ─────────────────────────────────────────────
    local decision
    decision=$(parse_review_decision "$design_dir/review.md")
    
    if [[ "$decision" == "pass" ]]; then
      echo ""
      separator "=" 50
      log_ok "Review PASSED!"
      log_info "Final plan: $design_dir/plan.md"
      log_info "Total iterations: $iter"
      separator "=" 50
      return $EXIT_PASS
    fi
    
    # Check for conflict (same issues repeating)
    if detect_conflict "$design_dir/history/" "$conflict_threshold"; then
      log_error "Conflict detected: same issues repeating $conflict_threshold+ times"
      log_info "Writer and Reviewer may be in a loop. Manual intervention needed."
      return $EXIT_CONFLICT
    fi
    
    log_warn "Review: needs revision. Continuing..."
    echo ""
  done
  
  log_error "Max iterations ($max_iter) reached without pass."
  log_info "The plan may need manual refinement or different approach."
  return $EXIT_MAX_ITER
}

# Parse review decision from review.md
parse_review_decision() {
  local review_file="$1"
  
  if [[ ! -f "$review_file" ]]; then
    echo "fail"
    return
  fi
  
  # Look for "PASS: true" or "**PASS**: true" pattern
  if grep -qiE '^\*?\*?PASS\*?\*?:\s*(true|yes)' "$review_file"; then
    echo "pass"
  else
    echo "fail"
  fi
}

# Detect conflict (same issues repeating)
detect_conflict() {
  local history_dir="$1"
  local threshold="${2:-3}"
  
  # Simple heuristic: check if last N reviews have similar issue titles
  local review_files
  review_files=$(ls -t "$history_dir"/review_v*.md 2>/dev/null | head -n "$threshold")
  
  if [[ $(echo "$review_files" | wc -l) -lt "$threshold" ]]; then
    # Not enough history
    return 1
  fi
  
  # Extract issue titles from each review and check for repeats
  local all_issues=""
  for file in $review_files; do
    # Extract lines matching "### [CATEGORY]: [Title]" pattern
    local issues
    issues=$(grep -E '^###\s+\[.*\]:' "$file" 2>/dev/null | sort)
    all_issues+="$issues"$'\n'
  done
  
  # Check if any issue appears threshold times
  local repeated
  repeated=$(echo "$all_issues" | sort | uniq -c | awk -v t="$threshold" '$1 >= t {print}')
  
  [[ -n "$repeated" ]]
}

# Resolve prompt path (local .design/prompts or crew home)
resolve_prompt_path() {
  local prompt_path="$1"
  local design_dir="$2"
  
  # Check local first
  if [[ -f "$design_dir/$prompt_path" ]]; then
    echo "$design_dir/$prompt_path"
    return
  fi
  
  # Check crew home
  local crew_home
  crew_home=$(get_crew_home)
  if [[ -f "$crew_home/$prompt_path" ]]; then
    echo "$crew_home/$prompt_path"
    return
  fi
  
  # Default prompts in crew home
  if [[ -f "$crew_home/prompts/cross-review/$(basename "$prompt_path")" ]]; then
    echo "$crew_home/prompts/cross-review/$(basename "$prompt_path")"
    return
  fi
  
  # Return as-is (will fail later if not found)
  echo "$prompt_path"
}

# Initialize design session
design_init() {
  local idea="$*"
  local design_dir=".design"
  
  if [[ -z "$idea" ]]; then
    log_error "Usage: design init <idea description>"
    return 1
  fi
  
  header "Initializing Design Session"
  
  # Create directory structure
  ensure_dir "$design_dir"
  ensure_dir "$design_dir/history"
  ensure_dir "$design_dir/prompts"
  
  # Save idea
  echo "$idea" > "$design_dir/idea.txt"
  log_ok "Saved idea to $design_dir/idea.txt"
  
  # Create default config
  local agent_type
  agent_type=$(get_agent_type "")
  
  cat > "$design_dir/design.yaml" << EOF
# Cross-Review Design Session
project: $(basename "$PWD")
agent: $agent_type
max_iterations: 5

termination:
  stale_threshold: 2
  conflict_threshold: 3

prompts:
  plan_writer: prompts/plan_writer.md
  reviewer: prompts/reviewer.md

history:
  enabled: true
  dir: history/
EOF
  log_ok "Created $design_dir/design.yaml"
  
  # Copy default prompts if not customized
  local crew_home
  crew_home=$(get_crew_home)
  
  if [[ -f "$crew_home/prompts/cross-review/plan_writer.md" ]]; then
    cp "$crew_home/prompts/cross-review/plan_writer.md" "$design_dir/prompts/"
    log_ok "Copied default plan_writer.md"
  fi
  
  if [[ -f "$crew_home/prompts/cross-review/reviewer.md" ]]; then
    cp "$crew_home/prompts/cross-review/reviewer.md" "$design_dir/prompts/"
    log_ok "Copied default reviewer.md"
  fi
  
  echo ""
  log_info "Design session initialized!"
  log_info "Run 'design review' to start cross-review loop"
}

# Show design status
design_status() {
  local design_dir=".design"
  
  if [[ ! -d "$design_dir" ]]; then
    log_error "No design session found. Run 'design init <idea>' first."
    return 1
  fi
  
  header "Design Session Status"
  
  # Config
  if [[ -f "$design_dir/design.yaml" ]]; then
    local agent
    agent=$(config_get ".agent" "claude" "$design_dir/design.yaml")
    local max_iter
    max_iter=$(config_get ".max_iterations" "5" "$design_dir/design.yaml")
    echo "Agent: $agent"
    echo "Max iterations: $max_iter"
  fi
  
  echo ""
  
  # Files
  echo "Files:"
  [[ -f "$design_dir/idea.txt" ]] && echo "  ✓ idea.txt"
  [[ -f "$design_dir/plan.md" ]] && echo "  ✓ plan.md"
  [[ -f "$design_dir/review.md" ]] && echo "  ✓ review.md"
  
  # History
  local history_count
  history_count=$(ls "$design_dir/history/"*.md 2>/dev/null | wc -l)
  echo ""
  echo "History: $history_count files"
  
  # Last review decision
  if [[ -f "$design_dir/review.md" ]]; then
    local decision
    decision=$(parse_review_decision "$design_dir/review.md")
    echo ""
    if [[ "$decision" == "pass" ]]; then
      echo -e "Last review: ${GREEN}PASS${NC}"
    else
      echo -e "Last review: ${YELLOW}NEEDS REVISION${NC}"
    fi
  fi
}

# Reset design session
design_reset() {
  local design_dir=".design"
  
  if [[ ! -d "$design_dir" ]]; then
    log_error "No design session found."
    return 1
  fi
  
  if confirm "Reset design session? This will delete plan.md, review.md, and history/"; then
    rm -f "$design_dir/plan.md" "$design_dir/review.md"
    rm -rf "$design_dir/history"
    ensure_dir "$design_dir/history"
    log_ok "Design session reset. idea.txt preserved."
  fi
}
