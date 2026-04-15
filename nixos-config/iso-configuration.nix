{ config, pkgs, modulesPath, ... }:

{
  # Import QEMU guest profile for generic x86_64
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Boot configuration for USB
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.supportedFilesystems = [ "ext4" "btrfs" "vfat" "ntfs" "xfs" ];
  
  # Enable flakes and channels
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.channel.enable = true;
  
  # Locale and timezone
  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "UTC";
  
  # Kernel modules for mesh networking
  boot.kernelModules = [ "batman-adv" "mac80211" "cfg80211" "wireguard" ];
  boot.extraModulePackages = with pkgs; [ ];

  # Networking
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 8000 8080 ];
  networking.firewall.allowedUDPPorts = [ 53 4567 ];
  
  # System packages
  environment.systemPackages = with pkgs; [
    # Network tools
    batctl iw wireless-tools iproute2 ethtool tcpdump iperf3 curl wget
    # Audio
    ffmpeg mplayer mpg123 opus-tools sox alsa-utils
    # Streaming
    icecast ezstream
    # Development
    go gcc git vim nano htop python3 python3Packages.pip
    # Utilities
    rsync nc telnet strace lsof jq bash
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
  
  # USB boot optimizations
  boot.initrd.systemd.enable = true;
  boot.supportExternalBus = true;
  
  # Documentation
  documentation.enable = true;
  
  # Auto-login for TUI
  services.getty.autologinUser = "mesh";
}