#!/bin/sh
# Build Script for Mesh Audio Network ISO

BUILD_DIR="${BUILD_DIR:-/build}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"
NIXOS_VERSION="24.05"

mkdir -p "$OUTPUT_DIR"

echo "============================================"
echo "  Mesh Audio Network - ISO Builder"
echo "============================================"
echo ""

# Add and update nixos channel
echo "📦 Adding NixOS channel..."
nix-channel --add "https://channels.nixos.org/nixos-${NIXOS_VERSION}" nixos
nix-channel --update

# Get NixOS path
NIXOS_PATH=$(nix-instantiate --find-file nixos)
echo "✅ NixOS path: $NIXOS_PATH"

# Create the configuration inline
cat > "$BUILD_DIR/configuration.nix" << 'NIXCONF'
{ config, pkgs, lib, ... }:

{
  imports = [
    # Import QEMU guest profile which includes ISO support
    "${NIXOS_PATH}/nixos/modules/profiles/qemu-guest.nix"
  ];

  # Boot
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.supportedFilesystems = [ "ext4" "btrfs" "vfat" ];

  # Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";

  # Mesh kernel modules
  boot.kernelModules = [ "batman-adv" "mac80211" "cfg80211" ];

  # Network
  networking.firewall.enable = false;

  # Packages
  environment.systemPackages = with pkgs; [
    batctl iw iproute2 ffmpeg mpg123 python3 curl wget git vim htop bash
  ];

  # Services
  services.openssh.enable = true;

  # Users
  users.users.mesh = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "mesh123";
  };
  users.users.root.initialPassword = "root123";

  # Sound
  sound.enable = true;

  # Auto-login
  services.getty.autologinUser = "mesh";
}
NIXCONF

echo ""
echo "🔨 Building ISO..."
echo "   This takes 60-120 minutes..."
echo ""

cd "$BUILD_DIR"

# Build using nix-build with the proper NixOS configuration
nix-build \
    --arg configuration ./configuration.nix \
    "${NIXOS_PATH}/nixos/default.nix" \
    -A config.system.build.isoImage \
    -o result 2>&1

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Checking result..."

if [ -d "result/iso" ]; then
    echo "✅ Build completed!"
    cp result/iso/*.iso "$OUTPUT_DIR/mesh-audio-network.iso"
    ls -lh "$OUTPUT_DIR/mesh-audio-network.iso"
elif [ -d "result/isoImage" ]; then
    cp result/isoImage/*.iso "$OUTPUT_DIR/mesh-audio-network.iso"
    ls -lh "$OUTPUT_DIR/mesh-audio-network.iso"
else
    echo "❌ Build may have failed"
    ls -la result/ 2>/dev/null || echo "No result directory"
fi

echo "============================================"