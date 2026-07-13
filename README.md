# tmux-herdr

A tmux plugin for [herdr](https://herdr.dev/), a persistent multiplexer for coding agents like Claude Code. It adds a status bar indicator for your agents' state, plus keybindings to open the dashboard, attach to an agent, or spin up a new one.

<!--
## Screenshots

TODO: add screenshot of the status bar indicator

TODO: add screenshot of the agent dashboard popup
-->

## Usage

### Status indicator

Add the placeholder `#{tmux_herdr_status}` anywhere inside your `status-left` or `status-right`, for example:

```tmux
set -g status-right '#{tmux_herdr_status}'
```

It renders three colored counters, one per agent state:

- **Green** -> idle / done agents
- **Yellow** -> working agents
- **Red** -> blocked agents

### Keybindings

All keybindings are triggered with your tmux prefix:

| Key          | Action                                                                                                                                                                              |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `prefix + h` | Open the herdr dashboard in a popup                                                                                                                                                |
| `prefix + a` | Attach to the agent for the current repo in a new pane (prompts with fzf if multiple agents match)                                                                                |
| `prefix + N` | Start a new agent for the branch currently checked out, create/reuse its workspace and worktree, and attach to it (reusing a shell pane if one is available, otherwise splitting) |
| `prefix + B` | Same as above, but first pick a branch with fzf in a popup                                                                                                                         |

## Installation

Make sure you have the following dependencies installed: [herdr](https://herdr.dev/docs/install/), `jq`, `fzf`, `git`.

### Tmux Plugin Manager (recommended)

Add this to your `.tmux.conf`:

```tmux
set -g @plugin 'ardubev16/tmux-herdr'
```

Then press `prefix + I` to install it.

### Manual

Clone the repo somewhere, e.g.:

```sh
git clone https://github.com/ardubev16/tmux-herdr.git ~/.tmux/plugins/tmux-herdr
```

Then source it from your `.tmux.conf`:

```tmux
run-shell ~/.tmux/plugins/tmux-herdr/main.tmux
```

> [!IMPORTANT]
> If you want the [status indicator](#status-indicator), make sure `status-left`/`status-right` are set **before** the line that loads this plugin.

## Configuration Options

The following configuration options (with defaults) are available:

```tmux
# Background color of the status segment
set -g @tmux_herdr_status_background 'colour238'

# Foreground color for idle/done agents
set -g @tmux_herdr_status_idle_foreground 'green'

# Foreground color for working agents
set -g @tmux_herdr_status_working_foreground 'yellow'

# Foreground color for blocked agents
set -g @tmux_herdr_status_blocked_foreground 'red'

# Direction of the split used to place a new agent's pane, when no existing
# shell pane is available to reuse ('h' for horizontal, 'v' for vertical)
set -g @tmux_herdr_split_direction 'h'

# Key that opens the herdr dashboard
set -g @tmux_herdr_key_dashboard 'h'

# Key that attaches to the agent for the current repo
set -g @tmux_herdr_key_attach 'a'

# Key that starts a new agent for the branch currently checked out
set -g @tmux_herdr_key_new_agent 'N'

# Key that starts a new agent, picking the branch with fzf in a popup
set -g @tmux_herdr_key_new_agent_branch 'B'
```
