{
  description = "Mesh Audio Network - Bootable USB ISO";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        
        # Songs list - embedded as base64 to avoid large files
        songs-list = [
          { id = "song_0000"; name = "Calm ambient synth"; genre = "ambient"; }
          { id = "song_0001"; name = "Energetic electronic"; genre = "electronic"; }
          { id = "song_0002"; name = "Melancholic piano"; genre = "classical"; }
          { id = "song_0003"; name = "Happy jazz guitar"; genre = "jazz"; }
          { id = "song_0004"; name = "Dark experimental"; genre = "experimental"; }
          { id = "song_0005"; name = "Dreamy ambient"; genre = "ambient"; }
          { id = "song_0006"; name = "Peaceful classical"; genre = "classical"; }
          { id = "song_0007"; name = "Intense rock beat"; genre = "rock"; }
          { id = "song_0008"; name = "Calm folk melody"; genre = "folk"; }
          { id = "song_0009"; name = "Energetic synth wave"; genre = "electronic"; }
        ];
        
        mesh-config = { config, pkgs, ... }: {
          imports = [ "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix" ];
          
          # Boot
          boot.loader.grub.enable = true;
          boot.loader.grub.efiSupport = true;
          boot.loader.grub.device = "/dev/sda";
          boot.supportedFilesystems = [ "ext4" "btrfs" "vfat" "ntfs" ];
          
          # Kernel modules for mesh networking
          boot.kernelModules = [ "batman-adv" "mac80211" "cfg80211" "wireguard" ];
          boot.extraModulePackages = with pkgs; [ ];
          
          # Enable flakes
          nix.settings.experimental-features = [ "nix-command" "flakes" ];
          nix.channel.enable = true;
          
          # Locale and timezone
          i18n.defaultLocale = "en_US.UTF-8";
          time.timeZone = "America/Mexico_City";
          
          # Networking
          networking.usePredictableInterfaceNames = false;
          networking.networkmanager.enable = true;
          networking.firewall.enable = true;
          networking.firewall.allowedTCPPorts = [ 22 8000 8080 ];
          networking.firewall.allowedUDPPorts = [ 53 4567 ];
          
          # System packages
          environment.systemPackages = with pkgs; [
            # Network tools
            batctl iw wireless-tools iproute2 ethtool tcpdump iperf3
            
            # Audio
            ffmpeg mplayer mpg123 opus-tools sox
            
            # Streaming
            icecast ezstream
            
            # Development
            go_1_21 gcc git vim nano htop curl wget
            
            # Languages
            python3 python3Packages.pip python3Packages.requests
            
            # Utilities
            rsync nc telnet strace lsof
          ];
          
          # Services
          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "yes";
          };
          
          services.icecast = {
            enable = true;
            configDir = "/etc/icecast";
          };
          
          services.timesyncd.enable = true;
          
          # Users
          users.users.mesh = {
            isNormalUser = true;
            description = "Mesh Audio Network User";
            extraGroups = [ "wheel" "audio" "network" ];
            initialPassword = "mesh123";
          };
          
          users.users.root.initialPassword = "root123";
          
          # Sound
          sound.enable = true;
          hardware.pulseaudio.enable = true;
          hardware.enableAllFirmware = true;
          
          # Systemd services for mesh
          systemd.services.mesh-agent = {
            description = "Mesh Audio Network Agent";
            wantedBy = [ "multi-user.target" ];
            after = [ "network.target" ];
            serviceConfig = {
              ExecStart = "${pkgs.go_1_21}/bin/go run /software/mesh-agent/main.go";
              Restart = "always";
              RestartSec = 10;
            };
          };
          
          systemd.services.mesh-api = {
            description = "Mesh API Server";
            wantedBy = [ "multi-user.target" ];
            after = [ "network.target" ];
            serviceConfig = {
              ExecStart = "${pkgs.python3}/bin/python3 -m http.server 8080";
              Restart = "always";
            };
          };
          
          systemd.services.mesh-monitor = {
            description = "Mesh Network Monitor";
            wantedBy = [ "graphical.target" ];
            after = [ "network.target" ];
            serviceConfig = {
              ExecStart = "${pkgs.go_1_21}/bin/go run /software/monitor/main.go";
              Restart = "always";
            };
          };
          
          # Documentation
          documentation.enable = true;
          
          # USB boot optimizations
          boot.initrd.systemd.enable = true;
          boot.supportExternalBus = true;
        };
        
        # Generate ISO configuration
        iso-config = { config, pkgs, ... }: {
          imports = [ mesh-config ];
          
          # ISO image settings
          isoImage.isoBaseName = "mesh-audio-network";
          isoImage.volumeID = "MESH-AUDIO";
          
          # Include songs and software
          environment.etc."mesh/songs".source = /Users/pabloflores/Documents/network_iso_minimax/songs;
          environment.etc."mesh/software".source = /Users/pabloflores/Documents/network_iso_minimax/software;
          
          nixpkgs.hostPlatform = "x86_64-linux";
        };
        
        # Build the ISO
        iso = (import nixpkgs { system = "x86_64-linux"; }).nixosSystem iso-config;
        
      in {
        packages.default = iso.config.system.build.isoImage;
        
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nix
            go_1_21
            python3
            ffmpeg
          ];
        };
        
        # Legacy support
        defaultPackage = iso.config.system.build.isoImage;
      }
    );
}