{
  description = "Mesh Audio Network ISO";
  
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  
  outputs = { self, nixpkgs }:
  let
    configuration = { config, pkgs, lib, ... }: {
      imports = [
        "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix"
      ];
      
      # Boot
      boot.loader.grub.enable = true;
      boot.loader.grub.device = "/dev/sda";
      boot.supportedFilesystems = [ "ext4" "vfat" ];
      
      # Enable flakes
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
      
      # Locale
      i18n.defaultLocale = "en_US.UTF-8";
      time.timeZone = "UTC";
      
      # Mesh networking
      boot.kernelModules = [ "batman-adv" "mac80211" "cfg80211" ];
      
      # Network
      networking.firewall.enable = false;
      
      # Packages
      environment.systemPackages = with pkgs; [
        batctl iw iproute2 ffmpeg mplayer mpg123
        python3 curl wget git vim htop
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
    };
  in {
    nixosConfigurations.iso = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ configuration ];
    };
  };
}
