{
  description = "Mesh Audio Network ISO";
  
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  
  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    
    configuration = { config, pkgs, ... }: {
      imports = [
        "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix"
      ];
      
      boot.loader.grub.enable = true;
      boot.loader.grub.device = "/dev/sda";
      boot.supportedFilesystems = [ "ext4" "vfat" ];
      
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
      
      i18n.defaultLocale = "en_US.UTF-8";
      time.timeZone = "UTC";
      
      boot.kernelModules = [ "batman-adv" "mac80211" "cfg80211" ];
      
      networking.firewall.enable = false;
      
      environment.systemPackages = with pkgs; [
        batctl iw iproute2 ffmpeg mplayer mpg123
        python3 curl wget git vim htop
      ];
      
      services.openssh.enable = true;
      
      users.users.mesh = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        initialPassword = "mesh123";
      };
      users.users.root.initialPassword = "root123";
      
      sound.enable = true;
    };
    
    isoSystem = (import nixpkgs {
      inherit system;
    }).nixosSystem {
      inherit configuration;
    };
  in
  {
    packages.${system}.default = isoSystem.config.system.build.isoImage;
    defaultPackage.${system} = isoSystem.config.system.build.isoImage;
  };
}
