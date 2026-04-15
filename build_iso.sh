#!/bin/sh
# Build Script for Mesh Audio Network ISO
# Uses nixpkgs to build NixOS

BUILD_DIR="/build"
OUTPUT_DIR="/output"
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

# Create a configuration that NixOS can use
cat > "$BUILD_DIR/config.nix" << EOF
{ config, pkgs, ... }:

{
  imports = [ 
    (builtins.fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/nixos-${NIXOS_VERSION}.tar.gz";
    }) + "/nixos/modules/installer/scan/not-detected.nix"
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
EOF

echo ""
echo "🔨 Building ISO..."
echo "   This takes 60-120 minutes..."
echo ""

cd "$BUILD_DIR"

# Try to build using nix-build with the channel's nixos
nix-build \
    --arg configuration ./config.nix \
    "$NIXOS_PATH" \
    -A config.system.build.isoImage \
    -o result 2>&1 || \

# Alternative: direct nix-build
nix-build \
    -I "nixos-config=./config.nix" \
    "<nixos>" \
    -A config.system.build.isoImage \
    -o result 2>&1

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Checking result..."

if [ -d "result" ]; then
    echo "✅ Build completed!"
    find result -name "*.iso" -exec cp {} "$OUTPUT_DIR/mesh-audio-network.iso" \; 2>/dev/null
    if [ -f "$OUTPUT_DIR/mesh-audio-network.iso" ]; then
        echo "📀 ISO: $OUTPUT_DIR/mesh-audio-network.iso"
        ls -lh "$OUTPUT_DIR/mesh-audio-network.iso"
    else
        find result -name "*.iso"
    fi
else
    echo "❌ Build failed or still in progress"
fi

echo "============================================"