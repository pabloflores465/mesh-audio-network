{ config, pkgs, ... }:

{
  imports = [ 
    (builtins.fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/nixos-24.05.tar.gz";
    }) + "/nixos/modules/profiles/installation-device.nix"
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