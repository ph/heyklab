{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../modules/roles/deployable.nix
    # ../../modules/roles/k8s.nix
    ../../modules/roles/vm.nix
    ../../modules/roles/nfs-ogdru-jahad.nix
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

    environment.systemPackages = with pkgs; [
      wget
      vim
      nfs-utils
    ];

    services.avahi = {
      nssmdns = true;
      enable = true;
      ipv4 = true;
      ipv6 = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };

    services.resolved = {
      enable = true;
      fallbackDns = [
        "8.8.8.8"
      ];
    };

    # Disable root login
    users.users.root.initialHashedPassword = lib.mkForce "!";

    networking = {
      hosts = {
        "192.168.1.152" = [ "ogdru-jahad" "ogdru-jahad.local" ];
      };

      useNetworkd = true;
      nftables.enable = true;
      firewall.filterForward = true;
      hostId = lib.mkDefault "deadbeef";
      hostName = lib.mkDefault "vm-boot";
    };

    system.stateVersion = config.system.nixos.release;
  };
}
