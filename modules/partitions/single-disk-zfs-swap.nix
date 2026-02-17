{ lib, ... }:
{
  disko.devices = {
    disk = {
      x = {
        type = "disk";
        device = lib.mkDefault "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
    };

    zpool = {
      zroot = {
        type = "zpool";
        rootFsOptions = {
          acltype = "posixacl";
          xattr = "sa";
          "com.sun:auto-snapshot" = "true";
        };
        datasets = {
          "root" = {
            type = "zfs_fs";
            mountpoint = "/";
          };
          "root/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              compression = "zstd";
            };
          };

          "root/longhorn-ext4" = {
            type = "zfs_volume";
            size = lib.mkDefault "100G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/mnt/longhorn-ext4";
              mountOptions = [
                "noatime"
                "discard"
              ];
            };
          };

          "root/swap" = {
            type = "zfs_volume";
            size = lib.mkDefault "8G";
            content = {
              type = "swap";
            };
            options = {
              volblocksize = "4096";
              compression = "zle";
              logbias = "throughput";
              sync = "always";
              primarycache = "metadata";
              secondarycache = "none";
              "com.sun:auto-snapshot" = "false";
            };
          };
        };
      };
    };
  };
}
