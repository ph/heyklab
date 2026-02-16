{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../modules/roles/deployable.nix
    ../../modules/roles/nix-background-tasks.nix
    ../../modules/roles/nix-settings.nix
    ../../modules/roles/k8s.nix
    ../../modules/roles/vm.nix
    ../../modules/roles/nfs-ogdru-jahad.nix
    ../../modules/secrets
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
      git
    ];

    services.avahi = {
      nssmdns4 = true;
      enable = true;
      ipv4 = true;
      ipv6 = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };

    # Disable root login
    users.users.root.initialHashedPassword = lib.mkForce "!";

    networking = {
      hosts = {
        "192.168.1.152" = [ "ogdru-jahad" "ogdru-jahad.local" ];
        "10.10.0.11" = [ "leviathan" ];
        "10.10.0.12" = [ "neferu" ];
        "10.10.0.13" = [ "nimue" ];
      };

      nameservers = [
        "10.43.0.10"
        "8.8.8.8"
        "1.1.1.1"
      ];

      nftables.enable = false;
      hostId = lib.mkDefault "deadbeef";
      hostName = lib.mkDefault "vm-boot";
    };

    # We use UTC here.
    time.timeZone = "UTC";

    # Synchronize server time with atomic clock.
    services.timesyncd.enable = true;

    system.stateVersion = config.system.nixos.release;
  };
}
