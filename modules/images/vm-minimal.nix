{
  pkgs,
  lib,
  disko,
  ...
}:
{
  modules = [
    disko.nixosModules.disko
    ./modules/partitions/single-disk-zfs-swap.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = lib.mkForce [
      "btrfs"
      "zfs"
      "vfat"
      "xfs"
      "ntfs"
      "cifs"
    ];
  };

  networking = {
    hostName = "vm";
  };
}
