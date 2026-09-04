# ghostmux CLI build configuration

# Path to scriptable-ghostty (sibling directory)
scriptable_ghostty := justfile_directory() / "../scriptable-ghostty"

default:
    @just --list

# Build with Swift Package Manager (debug)
build:
    swift build

# Check Swift formatting without rewriting files
lint:
    xcrun swift-format lint --strict --recursive Sources/

# Validate reviewed suppression/bypass inventory
check-suppressions:
    @bash Tests/suppression_guard.sh

# Run focused parser tests that do not require a live Ghostty socket
parser-test:
    swift test --filter GhostmuxCommandParsingTests

# Run the full local quality gate
verify: verify-tests verify-command-surface verify-suppressions verify-smoke
    @echo "ghostmux verify OK"

# Run build and formatting checks used by the local quality gate
verify-tests: build lint parser-test

# Check documented command surface used by the local quality gate
verify-command-surface: command-surface

# Validate suppression inventory used by the local quality gate
verify-suppressions: check-suppressions

# Run strict runtime smoke used by the local quality gate
verify-smoke:
    @env GHOSTMUX_SMOKE_ALLOW_SKIP=0 bash Tests/ghostmux_smoke.sh

# Check documented command surface against the real CLI registry
command-surface: build
    @bash Tests/command_surface_conformance.sh

# Install repo-local Git hooks for this clone
install-hooks:
    @git config --local core.hooksPath .githooks
    @chmod +x .githooks/pre-commit .githooks/pre-push
    @echo "Installed ghostmux Git hooks: pre-commit/pre-push run just verify"

# Build with Swift Package Manager (release)
build-release:
    swift build -c release

# Run smoke tests
test: build
    @bash Tests/ghostmux_smoke.sh

# Install to ~/.local/bin and materialize repo-local Git hooks
install: build-release install-hooks
    #!/usr/bin/env bash
    set -euo pipefail
    dest="$HOME/.local/bin"
    mkdir -p "$dest"
    # Install by atomic replacement, never by writing over the live binary.
    # A plain `cp` truncates and rewrites the destination inode in place, so any
    # concurrent exec of it reads a torn Mach-O and macOS SIGKILLs the process
    # (rc=137). `rm -f` first is not a fix either: the fresh file is still written
    # incrementally, so racing execs still see a partial image (SIGKILL, rc=127,
    # or a permanently wedged process). Staging beside the destination and
    # renaming makes the swap a single rename(2): every exec sees either the whole
    # old binary or the whole new one.
    trap 'rm -f "$dest"/.ghostmux.install.$$ "$dest"/.ghostchat.install.$$' EXIT
    for bin in ghostmux ghostchat; do
        staged="$dest/.$bin.install.$$"
        cp ".build/release/$bin" "$staged"
        chmod 755 "$staged"
        mv -f "$staged" "$dest/$bin"
    done
    echo "Installed ghostmux and ghostchat to $dest/"

# Build and install ScriptableGhostty (convenience)
install-ghostty:
    cd "{{ scriptable_ghostty }}" && just install

# Clean build artifacts
clean:
    swift package clean
    rm -rf .build

# Format Swift code
format:
    xcrun swift-format format -i -r Sources/
