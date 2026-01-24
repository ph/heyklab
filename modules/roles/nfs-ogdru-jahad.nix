{ pkgs, ... }:
{
  config = {
    environment.systemPackages = with pkgs; [ nfs-utils ];
    boot.supportedFilesystems = [ "nfs" ];
    fileSystems."/mnt/ogdru-jahad" = {
      device = "ogdru-jahad:/volume1/leviathan";
      fsType = "nfs4";
      options = [
        "defaults"
        "nofail"
      ];
    };
  };
}

    #   options = [
    #     "x-systemd.automount"
    #     "noauto"
    #     "x-systemd.idle-timeout=600"
    #   ];
    # };
