{
  description = "Mesh Audio Network ISO";
  
  inputs.nixpkgs.url = "channel:nixos-24.05";
  
  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    lib = nixpkgs.lib;
    
    configuration = { config, pkgs, ... }: {
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
    
    iso = lib.nixosSystem {
      inherit system;
      modules = [ configuration ];
    };
  in
  {
    packages.${system}.default = iso.config.system.build.isoImage;
    defaultPackage.${system} = self.packages.${system}.default;
  };
}
