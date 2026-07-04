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

# Run the full local quality gate
verify: build lint command-surface test
    @echo "ghostmux verify OK"

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
