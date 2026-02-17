{ pkgs, ... }:
{
  # config = {
  #   environment.systemPackages = with pkgs; [ nfs-utils ];
  #   boot.supportedFilesystems = [ "nfs" ];

  #   fileSystems."/mnt/ogdru-jahad/servers" = {
  #     device = "ogdru-jahad:/volume1/servers";
  #     fsType = "nfs4";
  #     options = [
  #       "x-systemd.automount"
  #       "noauto"
  #       "x-systemd.idle-timeout=60"
  #       "x-systemd.device-timeout=5s"
  #       "x-systemd.mount-timeout=5s"
  #     ];
  #   };

  #   fileSystems."/mnt/ogdru-jahad/music" = {
  #     device = "ogdru-jahad:/volume1/Music";
  #     fsType = "nfs4";
  #     options = [
  #       "x-systemd.automount"
  #       "noauto"
  #       "x-systemd.idle-timeout=60"
  #       "x-systemd.device-timeout=5s"
  #       "x-systemd.mount-timeout=5s"
  #     ];
  #   };
  # };
}
