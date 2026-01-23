{ ... }:
{
  config = {
    boot.supportedFilesystems = [ "nfs" ];

    systemd.mounts = [{
      type = "nfs";
      what = "ogdru-jahad:/volume1/leviathan";
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
