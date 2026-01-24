{ ... }:
{
  config = {
    fileSystems."/mnt/ogdru-jahad" = {
      device = "ogdru-jahad:/volume1/leviathan";
      fsType = "nfs";
    };
    boot.supportedFilesystems = [ "nfs" ];
    options = [
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=600"
    ];
  };
}
