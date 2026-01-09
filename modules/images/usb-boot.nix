{ config, lib, ... }:
{
  imports = [
    ../roles/deployable.nix
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


  system.stateVersion = config.system.nixos.release;
}
