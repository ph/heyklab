{ config, lib, ... }:
{
  imports = [
    ../../modules/roles/deployable.nix
    ../../modules/roles/vm.nix
  ];

  boot = {
    loader = {
      systemd-boot.enable = true; 
      efi.canTouchEfiVariables = true;
    };
    zfs.forceImportRoot = false;
    supportedFilesystems = lib.mkForce [
      "btrfs"
      "ext4"
      "zfs"
      "vfat"
      "xfs"
      "ntfs"
      "cifs"
    ];
  };

  # Disable root login
  users.users.root.initialHashedPassword = lib.mkForce "!";

  networking = {
    hostId = lib.mkDefault "deadbeef";
    hostName = lib.mkDefault "vm-boot";
  };

  system.stateVersion = config.system.nixos.release;
}
