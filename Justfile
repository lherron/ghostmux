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
    chmod +x ~/.local/bin/ghostmux
    @echo "Installed ghostmux to ~/.local/bin/ghostmux"

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
