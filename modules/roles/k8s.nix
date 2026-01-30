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

        # bootstrap flux via helm so we don't have to ever touch
        # the flux bootstrap cli.
        autoDeployCharts.flux2 = {
          name = "flux2";
          repo = "https://fluxcd-community.github.io/helm-charts";
          version = "2.17.2";
          hash = "sha256-4IsBS9VZR2ej5vV1P4OTsyc2Nr2bAu2DKnqbmivfbBM=";
          targetNamespace = "flux-system";
          createNamespace = true;
        };

        manifests.flux.content = [
          {
            apiVersion = "source.toolkit.fluxcd.io/v1beta1";
            kind = "GitRepository";
            metadata = {
              name = "my-repository";
              namespace = "flux-system";
            };
            spec = {
              interval = "1m";
              url = "https://github.com/ph/heyklab.git";
              ref = {
                branch = "main";
              };
            };
          }

          {
            apiVersion = "kustomize.toolkit.fluxcd.io/v1beta1";
            kind = "Kustomization";
            metadata = {
              name = "my-app";
              namespace = "flux-system";
            };
            spec = {
              interval = "1m";
              path = "./cluster";
              prune = true;
              sourceRef = {
                kind = "GitRepository";
                name = "my-repository";
                targetNamespace = "default";
              };
              url = "https://github.com/ph/heyklab.git";
              ref = {
                branch = "main";
              };
            };
          }
        ];
      }
      (lib.mkIf (cfg.mainServer != "" && !cfg.primary) {
        serverAddr = "https://${cfg.mainServer}:6443";
      })
    ];
  };
}
