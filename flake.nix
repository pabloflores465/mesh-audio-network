{
  description = "Mesh Audio Network ISO";
  
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  
  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
  in
  {
    nixosConfigurations.iso = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        "${nixpkgs}/nixos/modules/installer/scan/not-detected.nix"
        "${nixpkgs}/nixos/modules/profiles/installation-device.nix"
        
        {
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
          environment.systemPackages = with import nixpkgs { inherit system; }; [
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
        }
      ];
    };
    
    packages.${system}.default = self.nixosConfigurations.iso.config.system.build.isoImage;
    defaultPackage.${system} = self.packages.${system}.default;
  };
}
