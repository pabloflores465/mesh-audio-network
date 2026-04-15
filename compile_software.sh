#!/bin/bash
# Compile Go programs for the ISO
# Run this before building the ISO to compile binaries

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/software/build"
SRC_DIR="${SCRIPT_DIR}/software"

echo "============================================"
echo "  Compiling Mesh Software"
echo "============================================"

# Create build directory
mkdir -p "$BUILD_DIR"

# Check for Go
if ! command -v go &> /dev/null; then
    echo "❌ Go not installed"
    echo "Installing Go..."
    if command -v nix &> /dev/null; then
        nix-env -iA nixos.go_1_21
    else
        echo "Please install Go manually"
        exit 1
    fi
fi

echo "✅ Go found"
go version

# Compile mesh-agent
echo ""
echo "Compiling mesh-agent..."
cd "$SRC_DIR/mesh-agent"

# Create go.mod if not exists
if [ ! -f "go.mod" ]; then
    go mod init mesh-agent
fi

# Build for Linux
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o "$BUILD_DIR/mesh-agent" main.go
echo "✅ mesh-agent compiled"

# Compile monitor
echo ""
echo "Compiling monitor..."
cd "$SRC_DIR/monitor"

if [ ! -f "go.mod" ]; then
    go mod init mesh-monitor
fi

# Get dependencies
# go mod tidy

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o "$BUILD_DIR/mesh-monitor" main.go
echo "✅ mesh-monitor compiled"

# Compile api-server
echo ""
echo "Compiling api-server..."
cd "$SRC_DIR/api-server"

if [ ! -f "go.mod" ]; then
    go mod init mesh-api
fi

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o "$BUILD_DIR/mesh-api" main.go
echo "✅ mesh-api compiled"

echo ""
echo "============================================"
echo "  Build Complete!"
echo "============================================"
echo "Binaries: $BUILD_DIR"
ls -la "$BUILD_DIR"

echo ""
echo "Next steps:"
echo "1. Run build_iso.sh to create the ISO"
echo "2. Flash the ISO to a USB drive"
echo "3. Boot your hardware from USB"