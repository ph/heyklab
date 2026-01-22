{ ... }:
{
  config = {
    boot.supportedFilesystems = "nfs";
    services.rpcbind.enable = true;

    systemd.mounts = [{
      type = "nfs";
      what = "192.168.1.152:/volume1/leviathan";
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
