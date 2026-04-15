#!/bin/bash
# Quick Build Script for Mesh Audio Network ISO
# Builds NixOS ISO with mesh networking support
# Usage: ./quick-build.sh

set -e

NIXOS_VERSION="24.05"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/tmp/mesh-iso-build"
OUTPUT_DIR="$PROJECT_DIR/output"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║        Mesh Audio Network - Quick Build Script           ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Check if nix is available
if ! command -v nix &> /dev/null; then
    echo "❌ Nix not found. Installing..."
    curl -L https://nixos.org/nix/install -o /tmp/install-nix
    chmod +x /tmp/install-nix
    /tmp/install-nix --daemon --yes
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

echo "✅ Nix $(nix --version) ready"

# Create directories
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# Add NixOS channel
echo "📦 Setting up NixOS channel..."
nix-channel --add "https://channels.nixos.org/nixos-${NIXOS_VERSION}" nixos 2>/dev/null || true
nix-channel --update 2>/dev/null || true

# Get NixOS path
NIXOS_PATH=$(nix-instantiate --find-file nixos 2>/dev/null || echo "")
if [ -z "$NIXOS_PATH" ]; then
    echo "⚠️  Channel not ready, updating..."
    nix-channel --update
    NIXOS_PATH=$(nix-instantiate --find-file nixos)
fi
echo "✅ NixOS path: $NIXOS_PATH"

# Create configuration
cat > "$BUILD_DIR/configuration.nix" << 'EOF'
{ config, pkgs, ... }:

{
  imports = [ 
    (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-24.05.tar.gz") 
    + "/nixos/modules/installer/scan/not-detected.nix"
  ];

  # Boot configuration
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.supportedFilesystems = [ "ext4" "btrfs" "vfat" ];
  
  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.channel.enable = true;
  
  # Locale
  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "UTC";
  
  # Mesh networking
  boot.kernelModules = [ "batman-adv" "mac80211" "cfg80211" ];
  
  # Network
  networking.firewall.enable = false;
  networking.networkmanager.enable = true;
  
  # Packages
  environment.systemPackages = with pkgs; [
    batctl iw wireless-tools iproute2 ethtool
    ffmpeg mplayer mpg123 opus-tools sox
    python3 curl wget git vim nano htop
    go gcc networkmanager wpa_supplicant
  ];
  
  # Services
  services.openssh.enable = true;
  services.icecast.enable = true;
  services.timesyncd.enable = true;
  
  # Users
  users.users.mesh = {
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" "network" ];
    initialPassword = "mesh123";
  };
  users.users.root.initialPassword = "root123";
  
  # Sound
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  
  # Auto-login
  services.getty.autologinUser = "mesh";
}
EOF

echo ""
echo "🔨 Building ISO..."
echo "   This may take 60-120 minutes on first run."
echo "   Press Ctrl+C to cancel."
echo ""

cd "$BUILD_DIR"

# Build the ISO
nix-build \
    --arg configuration ./configuration.nix \
    "$NIXOS_PATH" \
    -A config.system.build.isoImage \
    -o result

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Build completed!"

# Copy ISO to output
if [ -d "result/iso" ]; then
    cp result/iso/*.iso "$OUTPUT_DIR/mesh-audio-network.iso"
elif [ -d "result/isoImage" ]; then
    cp result/isoImage/*.iso "$OUTPUT_DIR/mesh-audio-network.iso"
else
    find result -name "*.iso" -exec cp {} "$OUTPUT_DIR/mesh-audio-network.iso" \;
fi

if [ -f "$OUTPUT_DIR/mesh-audio-network.iso" ]; then
    echo "📀 ISO: $OUTPUT_DIR/mesh-audio-network.iso"
    ls -lh "$OUTPUT_DIR/mesh-audio-network.iso"
else
    echo "⚠️  ISO not found"
    ls -la result/
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                    Build Successful!                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "1. Flash to USB: sudo dd if=$OUTPUT_DIR/mesh-audio-network.iso of=/dev/sdX bs=4M"
echo "2. Boot from USB"
echo "3. Login: mesh / mesh123"
echo "4. Run mesh-monitor for TUI"