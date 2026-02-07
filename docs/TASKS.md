# crew - Development Tasks

**Last Updated**: 2026-02-06

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

### T001: Add input validation [M] - COMPLETED 2026-02-06
- [x] Create validate_agent_name() in lib/utils.sh
- [x] Create validate_file_path() to prevent path traversal
- [x] Create validate_interval() for numeric config values
- [x] Add validation to crew.sh (agent name inputs)
- [x] Add validation to design.sh (idea input)

### T002: Fix infinite restart loop [M] - COMPLETED 2026-02-06
- [x] Add restart_count and max_restarts to lib/watchdog.sh
- [x] Implement exponential backoff (capped at 300s)
- [x] Log when max restarts reached
- [x] Exit agent loop after max_restarts (5) hit

### T003: Add agent execution timeout [M]
- [ ] Use `timeout` command in lib/agent_runner.sh:94-139
- [ ] Make timeout configurable per agent
- [ ] Log when timeout occurs
- [ ] Handle timeout exit code (124)

### T004: Improve PID management [M] - COMPLETED 2026-02-06
- [x] Add flock-based file locking to lib/watchdog.sh
- [x] Graceful fallback for systems without flock
- [x] Handle PID reuse edge case

### T005: Add log rotation [S] - COMPLETED 2026-02-06
- [x] Implement size-based rotation (10MB max)
- [x] Rotate to .log.old on size threshold
- [x] Add rotate_log_if_needed() to lib/watchdog.sh

### T006: Extract magic numbers [S] - COMPLETED 2026-02-06
- [x] Move hardcoded values to named constants at file top
- [x] lib/watchdog.sh: DEFAULT_RESTART_DELAY, GRACEFUL_SHUTDOWN_TIMEOUT
- [x] lib/orchestrator.sh: conflict threshold
- [x] crew.sh: CREW_DIR constant

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

### T020: Add trap handlers [S] - COMPLETED 2026-02-06
- [x] Add _crew_cleanup() function to crew.sh and design.sh
- [x] Trap EXIT INT TERM signals
- [x] Ensure stop_all_agents called on exit

### T021: Improve config parsing errors [S]
- [ ] Make config_get failures more visible
- [ ] Add warning when using defaults
- [ ] Validate YAML parser availability at startup

### T022: Add strict mode to libraries [S] - COMPLETED 2026-02-06
- [x] Add set -euo pipefail to all lib/*.sh files
- [x] Use ${DEBUG:-} and ${CREW_AGENT:-} patterns for unbound vars

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

### T031: Create SECURITY.md [S] - COMPLETED 2026-02-06
- [x] Document trust boundaries
- [x] Explain prompt injection risks
- [x] Recommend input validation best practices
- [x] Document that crew should not be exposed to untrusted input

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

### T025: Add `crew edit` command [S] - 🔍 From Review
- [ ] Add `edit` case to crew.sh main dispatch
- [ ] Open `$CREW_DIR/prompts/<agent>.md` in `$EDITOR`
- [ ] Fall back to `vi` if `$EDITOR` not set
- [ ] Add usage to help text

### T026: Add JSON config fallback [S] - 🔍 From Review
- [ ] Update lib/config.sh to support `.crew/crew.json`
- [ ] Use Python's built-in `json` module (no pip needed)
- [ ] Try yq first, then JSON fallback
- [ ] Document in README

### T027: Add `working_dirs` advisory field [S] - 🔍 From Review
- [ ] Add `working_dirs` to default crew.yaml template
- [ ] Include in QA/DEV/JANITOR examples to show pattern
- [ ] Document as advisory (not enforced) in README
- [ ] Note: Phase 2 will add flock-based enforcement

### T028: Support `env` dictionary in config [S] - COMPLETED 2026-02-06 🔍 From Feedback
- [x] Update lib/watchdog.sh to read `env` map
- [x] Export variables in subshell via export_agent_env()
- [x] Allow cleaner crew.yaml without inline env vars

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

### D002: CD in agent_runner.sh [S] - COMPLETED 2026-02-06
- [x] Wrapped cd in subshells to avoid changing global state

### D003: Error handling in loops [M]
- Location: `lib/watchdog.sh:219-249`
- Issue: Loop continues on error, may miss issues
- Fix: Add error accumulation and reporting

### D004: Prompt file validation [S] - COMPLETED 2026-02-06
- [x] Added early validation with helpful error message

### D005: Inline env vars in command [M]
- Location: `crew.yaml` (user config)
- Issue: Users must put env vars in `command` string
- Fix: Implement T028 (`env` field) and migrate configs

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
- [x] Verify deployment in ai-judge - 2026-01-28
- [x] Fix critical bug: Multi-line config parsing - 2026-01-28
- [x] Fix critical bug: Prompt path resolution - 2026-01-28
- [x] T001: Input validation (agent names, file paths, intervals) - 2026-02-06
- [x] T002: Max restarts (5) with exponential backoff - 2026-02-06
- [x] T004: flock-based PID file locking - 2026-02-06
- [x] T005: Log rotation (10MB threshold) - 2026-02-06
- [x] T006: Extract magic numbers to named constants - 2026-02-06
- [x] T020: Trap handlers for graceful cleanup - 2026-02-06
- [x] T022: Strict mode in all library files - 2026-02-06
- [x] T028: Per-agent env config field - 2026-02-06
- [x] T031: SECURITY.md documentation - 2026-02-06
- [x] D002: CD wrapped in subshells - 2026-02-06
- [x] D004: Prompt file validation - 2026-02-06

