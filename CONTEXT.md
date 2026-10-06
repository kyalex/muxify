# Muxify

A personal macOS front end for tmux. It has a sidebar of tmux windows, a terminal showing the selected window, and a Right Panel for browsing the web or interacting with a simulated iPhone or iPad. tmux owns sessions, windows and panes; Muxify adds the Browser and Simulator.

## Language

### tmux

**Session**:
A tmux session, usually one per project. Sessions group Windows in the sidebar.
_Avoid_: project, workspace

**Window**:
A tmux window: the item you pick in the sidebar. Opening it shows all of its Panes.
_Avoid_: tab, workspace

**Pane**:
One split of a Window, laid out by tmux.
_Avoid_: split, terminal

### Browser

**Browser**:
The web browsing view in the Right Panel. Each Window has its own Browser and Tabs; switching Windows switches the Browser too.
_Avoid_: webview, inspector, sidebar browser

**Tab**:
One page in a Window's Browser, with its own back/forward history. "Tab" never means a tmux Window.
_Avoid_: page (when you mean the Tab itself), browser window

### Simulator

**Simulator**:
The interactive Device view in the Right Panel. It displays and controls one Device.
_Avoid_: Device Hub, mirror, simulator runtime

**Device**:
A simulated iPhone or iPad used to run and test apps. In Muxify, a Device never means a physical phone or tablet.
_Avoid_: simulator (when you mean the Device rather than its view), phone (when you also mean iPad)

### Agents

**Agent**:
A coding-agent CLI (Claude Code, Codex, OpenCode or Pi) running in a Pane, which reports its Status to Muxify through its Extension. The agent's own conversation is a "conversation", never a Session.
_Avoid_: bot, assistant, agent session

**Status**:
What an Agent is doing: working (a turn is running), blocked (waiting for the user to answer a permission prompt or question), done (the last turn ended, including by Esc) or failed (the last turn ended with an error). An Agent that has not run a turn yet has no Status.
_Avoid_: state, idle

**Unread**:
An Agent that reached done, failed or blocked while the user wasn't looking at its Window. Looking at the Window makes it read.
_Avoid_: unseen, new, notification

**Extension**:
The file or plugin folder installed into an Agent's own plugin or hook system that reports the Agent and its Status to Muxify.
_Avoid_: integration, hook (when you mean the whole file), plugin (when you mean ours)

### Layout

**Sidebar**:
The panel on the left of the Muxify window that lists Sessions, Windows and Agents.
_Avoid_: left sidebar, left panel

**Right Panel**:
The area beside the terminal that shows either the Browser or the Simulator, never both at once.
_Avoid_: right sidebar, browser panel (when you mean the container)

### Configuration

**Config**:
The Muxify config file: settings, in YAML sections, that control how Muxify itself behaves. It never holds what is open or shown now.
_Avoid_: settings, preferences, Muxify settings

**Ghostty config**:
The Ghostty config files that control the terminal: its fonts, theme and terminal keybinds.
_Avoid_: terminal config
