# Hardware configuration for NixOS ISO
# Generic x86_64 PC hardware

{ config, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" "batman-adv" "mac80211" "cfg80211" "wireguard" ];
  boot.extraModulePackages = [ ];

  # File systems
  fileSystems."/" = {
    device = "/dev/null";
    fsType = "tmpfs";
  };

  # EFI boot
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.grub.device = "nodev";

  # No swap (USB friendly)
  swap.enable = false;

  # CPU
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  # Network - include all common drivers
  networking.enable = true;
  boot.kernelModules = [ "e1000e" "rtl8168" "iwlwifi" "mt7601u" "brcmfmac" ];
  
  # Additional wireless support
  boot.extraModulePackages = with pkgs; [
    linuxPackages_bcachefs.bcachefs
  ];
  
  # USB audio support
  boot.extraModulePackages = with pkgs; [
    linuxPackages_6_6.acpi_call
  ];
  
  hardware.enableRedistributableFirmware = true;
  
  # Audio
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  
  # USB boot support
  boot.supportExternalBus = true;
  boot.initrd.systemd.enable = true;
}