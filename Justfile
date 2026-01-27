# ghostmux CLI build configuration

# Path to scriptable-ghostty (sibling directory)
scriptable_ghostty := justfile_directory() / "../scriptable-ghostty"

default:
    @just --list

# Build with Swift Package Manager (debug)
build:
    swift build

# Build with Swift Package Manager (release)
build-release:
    swift build -c release

# Run smoke tests
test:
    @bash Tests/ghostmux_smoke.sh

# Install to ~/.local/bin
install: build-release
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
    swift-format format -i -r Sources/
