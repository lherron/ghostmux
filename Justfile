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

# Run the full local quality gate
verify: verify-tests verify-command-surface verify-suppressions verify-smoke
    @echo "ghostmux verify OK"

# Run build and formatting checks used by the local quality gate
verify-tests: build lint

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
    @mkdir -p ~/.local/bin
    cp .build/release/ghostmux ~/.local/bin/ghostmux
    cp .build/release/ghostchat ~/.local/bin/ghostchat
    chmod +x ~/.local/bin/ghostmux ~/.local/bin/ghostchat
    @echo "Installed ghostmux and ghostchat to ~/.local/bin/"

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
