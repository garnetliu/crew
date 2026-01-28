# crew - Development Tasks

**Last Updated**: 2026-01-28

## Task Sizing

| Size | Effort |
|------|--------|
| S | < 1 hour |
| M | 1-4 hours |
| L | 4+ hours |

---

## P0: Critical Security & Reliability

### T000: Add .gitignore [S] - COMPLETED 2026-01-28
- [x] Create .gitignore with .crew/logs/, .crew/run/, .design/history/
- [x] Add docs/EVAL.md to gitignore (local only)
- [x] Include editor and OS-specific ignores

### T001: Add input validation [M] - HIGH PRIORITY
- [ ] Create validate_agent_name() in lib/utils.sh
- [ ] Create validate_file_path() to prevent path traversal
- [ ] Create validate_interval() for numeric config values
- [ ] Add validation to crew.sh:176-189 (agent name inputs)
- [ ] Add validation to design.sh:225-285 (idea input)

### T002: Fix infinite restart loop [M] - HIGH PRIORITY
- [ ] Add restart_count and max_restarts to lib/watchdog.sh:44-65
- [ ] Implement exponential backoff (5s, 10s, 20s, 40s...)
- [ ] Log when max restarts reached
- [ ] Exit agent loop after max_restarts hit

### T003: Add agent execution timeout [M]
- [ ] Use `timeout` command in lib/agent_runner.sh:94-139
- [ ] Make timeout configurable per agent
- [ ] Log when timeout occurs
- [ ] Handle timeout exit code (124)

### T004: Improve PID management [M]
- [ ] Add flock-based file locking to lib/watchdog.sh
- [ ] Store process start time in PID file
- [ ] Verify process name matches expected agent
- [ ] Handle PID reuse edge case

### T005: Add log rotation [S]
- [ ] Implement size-based rotation (10MB max)
- [ ] Rotate to .log.old on size threshold
- [ ] Add to lib/watchdog.sh:47

### T006: Extract magic numbers [S]
- [ ] Move hardcoded values to constants at file top
- [ ] lib/watchdog.sh: DEFAULT_RESTART_DELAY, GRACEFUL_SHUTDOWN_TIMEOUT
- [ ] lib/orchestrator.sh: conflict threshold
- [ ] crew.sh: CREW_DIR constant

---

## P1: Testing (Critical for Quality)

### T010: Set up test framework [M]
- [ ] Install bats-core for Bash testing
- [ ] Create tests/ directory structure (unit/, integration/, fixtures/)
- [ ] Add GitHub Actions CI configuration
- [ ] Document how to run tests in README

### T011: Unit tests for lib/utils.sh [S]
- [ ] Test log_* functions
- [ ] Test file_hash (md5/md5sum/fallback)
- [ ] Test ensure_dir
- [ ] Test command_exists

### T012: Unit tests for lib/config.sh [M]
- [ ] Test config_get with yq
- [ ] Test config_get with Python fallback
- [ ] Test validate_config with valid/invalid YAML
- [ ] Test get_agent_type precedence (env > config > default)

### T013: Unit tests for lib/orchestrator.sh [M]
- [ ] Test parse_review_decision (pass/fail detection)
- [ ] Test detect_conflict (issue repetition)
- [ ] Test resolve_prompt_path (local vs crew home)

### T014: Unit tests for lib/watchdog.sh [M]
- [ ] Test is_agent_running with mock PID files
- [ ] Test get_agent_status states
- [ ] Test start_agent / stop_agent lifecycle

### T015: Integration tests [L]
- [ ] End-to-end design init + design review (mock agent)
- [ ] End-to-end crew init + crew start + crew stop
- [ ] Test termination conditions (stale, conflict, pass)

---

## P2: Error Handling & Robustness

### T020: Add trap handlers [S]
- [ ] Add cleanup() function to crew.sh and design.sh
- [ ] Trap EXIT INT TERM signals
- [ ] Ensure stop_all_agents called on exit

### T021: Improve config parsing errors [S]
- [ ] Make config_get failures more visible
- [ ] Add warning when using defaults
- [ ] Validate YAML parser availability at startup

### T022: Add strict mode to libraries [S]
- [ ] Add set -euo pipefail to all lib/*.sh files
- [ ] Test that errors properly propagate

### T023: Improve conflict detection [M]
- [ ] Use fuzzy matching or keyword extraction
- [ ] Track issues by section location, not just title
- [ ] Check all history, not just last N reviews

---

## P3: Documentation

### T030: Add inline comments to lib modules [M]
- [ ] orchestrator.sh - document termination logic
- [ ] watchdog.sh - document PID management
- [ ] agent_runner.sh - document CLI abstraction

### T031: Create SECURITY.md [S]
- [ ] Document trust boundaries
- [ ] Explain prompt injection risks
- [ ] Recommend input validation best practices
- [ ] Document that crew should not be exposed to untrusted input

### T032: Add --help examples [S]
- [ ] Improve design --help with more examples
- [ ] Improve crew --help with troubleshooting section
- [ ] Add common error messages and fixes

---

## P4: Features

### T020: Agent-to-agent coordination [L]
- [ ] Design shared context mechanism
- [ ] Implement `.crew/shared/` for inter-agent state
- [ ] Add file locking to prevent conflicts
- [ ] Document coordination patterns

### T021: Result aggregation [M]
- [ ] Collect agent outputs after run
- [ ] Generate summary report
- [ ] Detect conflicting changes

### T022: Dry-run mode [S]
- [ ] Add `--dry-run` flag to `design review`
- [ ] Print what would happen without executing
- [ ] Useful for testing prompt changes

### T023: Agent templates [M]
- [ ] Create template system for common agent roles
- [ ] Templates: qa, dev, janitor, security, docs
- [ ] `crew template list` / `crew template use <name>`

### T024: Configuration validation [S]
- [ ] Validate prompt files exist
- [ ] Validate agent commands are executable
- [ ] Show helpful errors for misconfigurations

---

## P5: Improvements

### T030: Better error messages [S]
- [ ] Wrap errors with context (which function, what input)
- [ ] Suggest fixes for common problems
- [ ] Color-code error severity

### T031: Performance optimization [M]
- [ ] Reduce subprocess spawning in hot paths
- [ ] Cache yq/python availability check
- [ ] Optimize file hash for large files

### T032: Shell compatibility [M]
- [ ] Test with bash 4.x, 5.x
- [ ] Test with zsh (if feasible)
- [ ] Document minimum bash version

### T033: Configurable restart policy [S]
- [ ] Add `restart_delay` to config
- [ ] Add `max_restarts` limit
- [ ] Add `restart_on_error` toggle

---

## Technical Debt

### D001: Remove hardcoded defaults [S]
- Location: `lib/watchdog.sh:8-10`
- Issue: `DEFAULT_CHECK_INTERVAL=30` should come from config
- Fix: Read from config with fallback

### D002: CD in agent_runner.sh [S]
- Location: `lib/agent_runner.sh:103,119,135`
- Issue: `cd "$working_dir"` changes global state
- Fix: Use subshell `(cd "$working_dir" && ...)`

### D003: Error handling in loops [M]
- Location: `lib/watchdog.sh:219-249`
- Issue: Loop continues on error, may miss issues
- Fix: Add error accumulation and reporting

### D004: Prompt file validation [S]
- Location: `lib/orchestrator.sh:72`
- Issue: Missing prompt file causes cryptic error
- Fix: Early validation with helpful message

---

## Completed

- [x] Initial project structure - 2026-01-28
- [x] Design mode implementation - 2026-01-28
- [x] Crew mode implementation - 2026-01-28
- [x] CLAUDE.md documentation - 2026-01-28
- [x] PRD.md documentation - 2026-01-28
- [x] ARCHITECTURE.md documentation - 2026-01-28
- [x] TASKS.md development backlog - 2026-01-28
- [x] SESSION_LOG.md checkpoint log - 2026-01-28
- [x] Code review (docs/EVAL.md) - 2026-01-28
- [x] Create .gitignore - 2026-01-28
