# Taproom

A Flutter desktop frontend for Homebrew: browse what's installed, see and
apply upgrades, search formulae and casks, and explore your taps.

It drives the `brew` CLI directly (JSON output for queries, streamed output
for installs), so it needs Homebrew at `/opt/homebrew` or `/usr/local` and
runs **without the macOS App Sandbox** (see `macos/Runner/*.entitlements`),
since a sandboxed app can't launch `brew`.

Casks whose installers need `sudo` prompt for your password via a native
dialog (a `SUDO_ASKPASS` helper written to the temp dir at launch).

## Develop

Tasks are defined in `Taskfile.yml` ([go-task](https://taskfile.dev),
`brew install go-task`); run `task` to list them.

    task run     # debug build; needs full Xcode, not just the Command Line Tools
    task check   # format check + analyze + tests (tests include read-only
                 # checks against your real brew)
    task install # release build copied to /Applications
