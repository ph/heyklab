{ ... }:
{
  config = {
    boot.supportedFilesystems = [ "nfs" ];
    services.rpcbind.enable = true;

    systemd.mounts = [{
      type = "nfs";
      what = "ogdru-jahad.local:/volume1/leviathan";
      where = "/mnt/ogdru-jahad";
    }];

    systemd.automounts = [{
      wantedBy = [ "multi-user.target" ];
      automountConfig = {
        TimeoutIdleSec = "600";
      };
      where = "/mnt/ogdru-jahad";
    }];
  };
}
