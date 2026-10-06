# Muxify

A native macOS app for running coding agents in tmux. It lists your tmux
Sessions and Windows in a sidebar, shows which Agents (Claude Code, Codex,
OpenCode, Pi) are working, blocked or done and waiting for you, and gives every
Window its own browser panel for docs and dev servers.

## How it works

Muxify runs a single `tmux attach` client in a libghostty terminal, so tmux
draws your Windows and Panes exactly as it does in Ghostty, with your
`~/.config/ghostty/config`. A tmux control-mode client and a once-a-second poll
keep the sidebar in sync, and Muxify keeps its own state (Browser Tabs, Agent
Statuses) in tmux options on the Window or Pane it belongs to, so it survives a
relaunch and goes away with the Window. Agents report their Status through small
Extensions installed into each Agent's own hook or plugin system. The vocabulary
is in [CONTEXT.md](CONTEXT.md), the design decisions in [docs/adr](docs/adr).

## Download the beta

Download an Apple-silicon ZIP from [GitHub Releases](https://github.com/ykaratkou/muxify/releases),
unzip it, and move `Muxify.app` into `/Applications`. Requires macOS 14+ and
`tmux` (`brew install tmux`). Ghostty and its resources are bundled; Ghostty,
Zig, and Xcode do not need to be installed to run the beta.

Betas are **ad-hoc signed, not Developer ID signed or notarized**. After trying
to open the app, macOS may block it. For a download you trust, use **System
Settings → Privacy & Security → Open Anyway** for Muxify and confirm. Do not
disable Gatekeeper globally.

Each release includes `SHA256SUMS`. Download it alongside the ZIP and run
`shasum -a 256 -c SHA256SUMS` in that directory to check file integrity. This
does not authenticate the publisher.

## Build

Requires macOS 14+ on Apple silicon, Xcode 26+, and Homebrew. Running the app
also requires `tmux`.

```sh
make run    # vendors libghostty, generates the Xcode project, builds and opens the app
```

`make setup`, which app build targets run first, prepares a fresh machine: it
installs `xcodegen` with Homebrew if it is missing, then runs
`scripts/setup-ghostty.sh` if the library or resources are not vendored yet. The
script builds the exact commit in `scripts/ghostty-version.env`, in the ignored
`vendor/ghostty-src/` directory. It downloads that commit's exact Zig compiler
with a SHA-256 check and installs Xcode's Metal Toolchain if missing. The library,
terminfo, themes, shell integration, and upstream dependency notices are vendored
together; an installed Ghostty.app is not used.

Explicit development overrides (not accepted by release packaging):

```sh
GHOSTTYKIT=/path/to/GhosttyKit.xcframework \
  GHOSTTY_RESOURCES=/path/to/ghostty/zig-out/share \
  ./scripts/setup-ghostty.sh
GHOSTTY_SRC=~/src/ghostty ./scripts/setup-ghostty.sh    # builds it with zig
```

If a custom checkout requires another Zig version, set `ZIG=/path/to/zig`.
For prebuilt development overrides, `GHOSTTY_NOTICES=/path/to/notices.txt` can
supply the matching build's dependency notices. To refresh the default pinned
library and resources, run `./scripts/setup-ghostty.sh` without overrides.

## Beta releases

The [release workflow](.github/workflows/release-beta.yml) runs on `macos-26`
with Xcode 26.6. It caches the pinned Ghostty build, tests Muxify, builds a Release
app, verifies its ad-hoc signature, and publishes a **GitHub prerelease**, never
the latest stable release. No Apple account or signing secrets are needed.
Pull requests and pushes to `master`/`main` run the tests without publishing.
Default-branch builds warm the dependency cache that beta tags can reuse
(GitHub does not share tag-only caches between different tags).

After committing and pushing the release tooling and app changes, publish a beta:

```sh
git tag v0.1.0-beta.1
git push origin v0.1.0-beta.1
```

The version must use `vMAJOR.MINOR.PATCH-beta.N` with a positive beta number.
The app's marketing version comes from the tag and its build number from the
GitHub Actions run number. The workflow can also be dispatched manually with an
existing beta tag. It refuses to replace an existing GitHub release; use a new
beta tag instead.

To test the tooling or build the same package locally without publishing:

```sh
make test-release
make test
make release TAG=v0.1.0-beta.1 BUILD_NUMBER=1
```

Packages are written under `build/releases/<tag>/`: the ZIP, `SHA256SUMS`,
release notes, and build provenance. Dependency notices are bundled under
`Muxify.app/Contents/Resources/ThirdPartyNotices/`.

## Install

```sh
make install    # a Release build, into /Applications (or INSTALL_DIR)
```

Then open the installed app and, from the **Muxify** menu:

- **Install Command Line Tool** links `muxify` into `~/.local/bin`. Programs in
  a Pane use it to open Tabs in their Window's Browser (`muxify browser open
  localhost:3000`), and launchers use it to jump to a Session (`muxify session
  open "my project"`). The link points into the app bundle, so install it from
  the copy you keep.
- **Install Extensions** installs or updates the status Extension for every
  supported Agent it finds in your home directory: Claude Code, Codex, OpenCode
  and Pi. Claude Code and Codex need `jq`. For Codex, trust the hooks once with
  `/hooks` and launch it with `codex --no-daemon`. Restart running Agents to
  load the Extension. See [extensions/README.md](extensions/README.md) for what
  each one does.

## Keybindings

Muxify's configurable keybindings work throughout the app, including in the
Browser. See [Keybindings](docs/keybindings.md) for all actions, default
shortcuts, a complete Config example, and built-in app and Browser shortcuts.
