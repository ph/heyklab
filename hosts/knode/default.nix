{ config, lib, pkgs, ... }:
{
  imports = [
    ../../modules/roles/deployable.nix
    ../../modules/roles/k8s.nix
    ../../modules/roles/vm.nix
  ];

  config = {
    boot = {
      loader = {
        systemd-boot.enable = true; 
        efi.canTouchEfiVariables = true;
      };
      zfs.forceImportRoot = false;
      supportedFilesystems = lib.mkForce [
        "ext4"
        "zfs"
        "vfat"
        "ntfs"
      ];
    };

    environment.systemPackages = with pkgs; [ wget vim tree ];

    # Disable root login
    users.users.root.initialHashedPassword = lib.mkForce "!";

    networking = {
      useNetworkd = true;
      nftables.enable = true;
      firewall.filterForward = true;
      hostId = lib.mkDefault "deadbeef";
      hostName = lib.mkDefault "vm-boot";
    };

    system.stateVersion = config.system.nixos.release;
  };
}
