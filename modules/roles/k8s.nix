{ config, lib, ... }:
let
  cfg = config.custom.k8s;
in {
  options.custom.k8s = {
    primary = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    mainServer = lib.mkOption {
      type = lib.types.string;
    };

    token = lib.mkOption {
      type = lib.types.str;
      default = "mysecret";
    };
  };

  config = {
    networking.firewall.allowedTCPPorts = [
      6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
      # 2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
      # 2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
    ];
    networking.firewall.allowedUDPPorts = [
      # 8472 # k3s, flannel: required if using multi-node for inter-node networking
    ];

    services.k3s = lib.mkMerge [
      {
        enable = true; 
        token = cfg.token;
        role = "server";
        clusterInit = cfg.primary;
        extraFlags = toString [
          "--debug" # Optionally add additional args to k3s
        ];
      }
      (lib.mkIf cfg.mainServer {
        serverAddr = "https://${cfg.mainServer}:6443";
      })
    ];
  };
}
