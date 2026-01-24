{ pkgs, ... }:
{
  config = {
    environment.systemPackages = with pkgs; [ nfs-utils ];
    boot.supportedFilesystems = [ "nfs" ];

    fileSystems."/mnt/ogdru-jahad/leviathan" = {
      device = "ogdru-jahad:/volume1/leviathan";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=60"
        "x-systemd.device-timeout=5s"
        "x-systemd.mount-timeout=5s"
      ];
    };
  };
}
