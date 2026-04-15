# NixOS ISO Configuration for Mesh Audio Network
# Bootable USB with mesh networking and distributed audio streaming

{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Boot configuration
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.grub.device = "/dev/sda";
  
  # Network configuration
  networking.usePredictableInterfaceNames = false;
  
  # Enable mesh networking
  boot.kernelModules = [ "batman-adv" "mac80211" "cfg80211" ];
  
  # SSH for remote management
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  
  # Timezone and locale
  time.timeZone = "America/Mexico_City";
  i18n.defaultLocale = "en_US.UTF-8";
  
  # User configuration
  users.users.root = {
    initialPassword = "mesh123";
    hashedPassword = "$6$rounds=4096$saltsalt$hashhash";
  };
  
  users.users.mesh = {
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" "network" ];
    initialPassword = "mesh123";
  };
  
  # Essential packages
  environment.systemPackages = with pkgs; [
    # Network tools
    batctl
    iw
    wireless-tools
    iproute2
    ethtool
    tcpdump
    iperf3
    
    # Audio
    ffmpeg
    mplayer
    mpg123
    opus-tools
    sox
    
    # Streaming
    icecast
    ezstream
    
    # Development
    go_1_21
    gcc
    git
    vim
    nano
    htop
    
    # System
    networkmanager
    dbus
    iwd
    wpa_supplicant
    
    # Python for scripts
    python3
    python3Packages.pip
    python3Packages.requests
  ];
  
  # NetworkManager for mesh
  networking.networkmanager.enable = true;
  
  # Mesh configuration
  # batman-adv will be configured by mesh-agent service
  
  # Sound configuration
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  
  # Create mesh user services
  systemd.services.mesh-agent = {
    description = "Mesh Audio Network Agent";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.go_1_21}/bin/go run /mesh-agent/main.go";
      Restart = "always";
      RestartSec = 10;
    };
  };
  
  # Icecast streaming service
  systemd.services.icecast = {
    description = "Audio Streaming Server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.icecast}/bin/icecast -c /etc/icecast.xml";
      Restart = "always";
    };
  };
  
  # API Server for master control
  systemd.services.mesh-api = {
    description = "Mesh API Server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.go_1_21}/bin/go run /api-server/main.go";
      Restart = "always";
      Port = 8080;
    };
  };
  
  # TUI Monitor service
  systemd.services.mesh-monitor = {
    description = "Mesh Network Monitor";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.go_1_21}/bin/go run /monitor/main.go";
      Restart = "always";
    };
  };
  
  # Enable services
  services.icecast.enable = true;
  services.icecast.configDir = "/etc/icecast";
  
  # Open firewall ports
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 8000 8080 22 ];
  networking.firewall.allowedUDPPorts = [ 53 67 68 1194 ];
  
  # Hostname based on MAC for unique identification
  systemd.network.wait-for-online = {
    anyInterface = true;
    timeout = 30;
  };
  
  # Systemd network config for mesh
  networking.useDHCP = true;
  
  # Power management - keep running
  powerManagement.enable = false;
  
  # Virtualization support for testing
  virtualisation.docker.enable = false;
  
  # Sound card configuration (auto-detect)
  hardware.enableAllFirmware = true;
  
  # NTP for time sync
  services.timesyncd.enable = true;
  services.timesyncd.servers = [ "pool.ntp.org" ];
  
  # Login configuration
  services.getty.autologinUser = "mesh";
  
  # Console font
  console.font = "Lat15-Fixed16";
  console.keyMap = "us";
  
  # NixOS channel
  nix.channel.enable = true;
  nix.settings substituters = [ "https://cache.nixos.org" ];
  nix.settings trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFG5cSKWhX0=" ];
  
  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Build ISO with GRUB
  nixpkgs.hostPlatform = "x86_64-linux";
  
  # Documentation
  documentation.enable = true;
  documentation.dev.enable = false;
}