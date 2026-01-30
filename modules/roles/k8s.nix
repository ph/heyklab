{ config, lib, pkgs, ... }:
let
  cfg = config.custom.k8s;
in {
  options.custom.k8s = {
    primary = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    mainServer = lib.mkOption {
      type = lib.types.str;
    };

    tokenPath = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/token";
    };
  };

  config = {
    environment.variables = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };

    environment.systemPackages = with pkgs; [
      kubectl
    ];
    
    networking.nftables.enable = true;
    networking.firewall = {
      allowedTCPPorts = [
        6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
        2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
        2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
      ];

      allowedUDPPorts = [
        8472 # k3s, flannel: required if using multi-node for inter-node networking
      ];
    };

    services.k3s = lib.mkMerge [
      
      {
        # manifests.nginx.source = ../../manifests/fluxcd.yaml;
        enable = true; 
        role = "server";
        clusterInit = cfg.primary;
        extraFlags = toString [
          "--token-file ${cfg.tokenPath}"
          #   "--debug" # Optionally add additional args to k3s
        ];

        # bootstrap flux via helm so we don't have to ever touch
        # the flux bootstrap cli.
        autoDeployCharts.flux2 = {
          name = "flux2";
          repo = "oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator";
          digest = "sha256-ebojOaEhhpxh/jpHwsZAewBKC7TK9wTDnTOdJBQYLc8=";
          version = "0.40.0";
          targetNamespace = "flux-system";
          createNamespace = true;
        };
      }
      (lib.mkIf (cfg.mainServer != "" && !cfg.primary) {
        serverAddr = "https://${cfg.mainServer}:6443";
      })
    ];
  };
}
