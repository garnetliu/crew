# crew

> Multi-Agent Orchestration Tool for AI-assisted development

## Overview

`crew` provides two distinct modes for AI agent orchestration:

| Command | Mode | Use Case |
|---------|------|----------|
| `design` | Cross-Review | Refine ideas into polished design docs |
| `crew` | Parallel Agents | Run multiple AI agents for debugging/optimization |

## Installation

```bash
git clone https://github.com/YOUR_USERNAME/crew ~/dev/crew
cd ~/dev/crew
./install.sh
```

This creates symlinks in `~/.local/bin`. If not already in PATH, add to your shell config:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Requires:
- `yq` for YAML parsing: `brew install yq`
- An AI CLI: `claude`, `opencode`, or `gemini`

## `design` - Cross-Review Mode

Turn ideas into refined design documents through automated Writer ⇄ Reviewer loops.

```bash
# Initialize with your idea
design init "A CLI tool for managing container deployments"

# Start cross-review loop
design review

# Check status
design status
```

### How it works

```
┌──────────────┐    trigger     ┌──────────────┐
│ Plan Writer  │ ──────────────→│   Reviewer   │
│    Agent     │                │    Agent     │
└──────────────┘                └──────────────┘
       ↑                               │
       │ trigger (if !pass)            │ pass?
       └───────────────────────────────┘
```

### Termination Conditions

- **pass**: Reviewer approves the plan
- **stale**: Plan unchanged for 2 iterations
- **conflict**: Same issues repeat 3+ times

### Files

```
.design/
├── design.yaml     # Config
├── idea.txt        # Your initial idea
├── plan.md         # Current plan
├── review.md       # Current review
└── history/        # All iterations
```

## `crew` - Parallel Agents Mode

Run multiple AI agents in parallel for continuous codebase improvement.

```bash
# Initialize in your project
crew init

# Start all agents
crew start

# Start specific agents
crew start QA DEV

# Monitor real-time
crew monitor

# View logs
crew logs QA

# Stop all
crew stop
```

### Configuration

Edit `.crew/crew.yaml`:

```yaml
project: my-project
check_interval: 30

agents:
  - name: QA
    icon: 🔴
    command: claude --dangerously-skip-permissions
    prompt: prompts/qa.txt
    interval: 10
    timeout: 600

  - name: DEV
    icon: 🔵
    command: claude --dangerously-skip-permissions
    prompt: prompts/dev.txt
```

### Files

```
.crew/
├── crew.yaml       # Config
├── prompts/        # Agent prompts
├── logs/           # Agent logs
└── run/            # PID files
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `CREW_AGENT` | Override default agent type (claude, opencode, gemini) |
| `DEBUG` | Set to `1` for verbose output |

## Examples

### Design a new feature

```bash
cd ~/dev/my-app
design init "Add real-time collaboration with WebSockets"
design review --max-iter 3
# Result: .design/plan.md with refined design
```

### Run parallel debugging agents

```bash
cd ~/dev/my-app
crew init
# Edit .crew/crew.yaml and prompts
crew start QA DEV
crew monitor
# Agents run continuously, finding and fixing issues
crew stop
```

## License

MIT
