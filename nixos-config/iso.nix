# ISO Image Configuration for Mesh Audio Network
# Generates bootable USB ISO

{ config, pkgs, ... }:

let
  mesh-songs = import ./songs-dist.nix;
in {
  imports = [
    ./configuration.nix
  ];

  # ISO Image settings
  isoImage = {
    # Contents of the ISO
    contents = [
      # Include mesh agent binary
      { source = /mesh-agent; target = "/mesh-agent"; }
      # Include monitor binary  
      { source = /monitor; target = "/monitor"; }
      # Include API server binary
      { source = /api-server; target = "/api-server"; }
      # Include songs
      { source = /songs; target = "/songs"; }
      # Include configuration
      { source = /etc/mesh; target = "/etc/mesh"; }
    ];
    
    # Populate ISO with files
    populateCache = ''
      mkdir -p $out/mesh
      cp -r /mesh-agent $out/mesh/
      cp -r /monitor $out/mesh/
      cp -r /api-server $out/mesh/
      cp -r /songs $out/mesh/
      mkdir -p $out/mesh/config
      cp /etc/mesh/*.yaml $out/mesh/config/ 2>/dev/null || true
    '';
    
    # Boot menu label
    label = "MESH-AUDIO-NETWORK";
    
    # Compress ISO
    compressionType = "gzip";
  };

  # System build configuration
  system.build = {
    # The ISO image
    isoImage = (import <nixpkgs/nixos> {
      inherit configuration;
    }).config.system.build.isoImage;
    
    # Kernel and initrd
    kernel = config.system.build.kernel;
    initrd = config.system.build.initrd;
    
    # GRUB menu
    grubMenuEntries = [
      "Mesh Audio Network (Default)"
      "Mesh Audio Network (Safe Mode)"
      "Mesh Audio Network (Debug)"
    ];
  };

  # Boot options
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200"
    "net.ifnames=0"
    "bios.devname=0"
  ];
}