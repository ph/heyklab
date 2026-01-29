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
    # TODO: check
    # assertions = [
    #   {
    #     assertion = cfg.tokenPath != null && cfg.tokenPath != "";
    #     message = "k3s token path secret must be configured";
    #   }
    # ];

    environment.variables = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };

    environment.systemPackages = with pkgs; [
      kubectl
      fluxcd
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

    # systemd.services.k3s = {
    #   wants = [ "network-online.target" "sops-nix.service" ];
    #   after = [ "network-online.target" "sops-nix.service" ];
    #   requires = [ "sops-nix.service" ];
    # };

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

        autoDeployCharts.flux2 = {
          name = "flux2";
          repo = "https://fluxcd-community.github.io/helm-charts";
          version = "2.17.2";
          hash = "e08b014bd5594767a3e6f5753f8393b3273636bd9b02ed832a7a9b9a2bdf6c13";

        };
      }
      (lib.mkIf (cfg.mainServer != "" && !cfg.primary) {
        serverAddr = "https://${cfg.mainServer}:6443";
      })
    ];
  };
}
