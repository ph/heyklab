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
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.bridge.bridge-nf-call-iptables" = 1;
      "net.bridge.bridge-nf-call-ip6tables" = 1;
    };

    boot.kernelModules = [
      "br_netfilter"
      "overlay"
      "vxlan"
    ];

    networking.nat = {
      enable = true;
      externalInterface = "ens18";
      internalInterfaces = [ "cni0" "flannel.1" ];
    };

    environment.variables = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };

    environment.systemPackages = with pkgs; [
      kubectl
      fluxcd
      cilium-cli
      kubernetes-helm
    ];
    
    networking.nftables.enable = false;
    networking.firewall = {
      allowedTCPPorts = [
        6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
        2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
        2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
        80 # HTTP
        443 # HTTPS
        5001 # Embedded registry (spegel)
        9100 # Node exporter
      ];
      allowedUDPPorts = [
        8472 # k3s, flannel: required if using multi-node for inter-node networking
      ];
    };

    # virtualisation.containerd = {
    #   enable = true;
    #   settings =
    #     let
    #       fullCNIPlugins = pkgs.buildEnv {
    #         name = "full-cni";
    #         paths = with pkgs;[
    #           cni-plugins
    #           cni-plugin-flannel
    #         ];
    #       };
    #     in {
    #       plugins."io.containerd.grpc.v1.cri" = {
    #         cni = {
    #           bin_dir = "${fullCNIPlugins}/bin";
    #           conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d/";
    #         };

    #         containerd = {
    #           snapshotter = "zfs";
    #         };
    #       };
    #     };
    # };

    services.k3s = lib.mkMerge [
      {
        enable = true;
        role = "server";
        clusterInit = cfg.primary;
        extraFlags = [
          "--token-file ${cfg.tokenPath}"
          "--container-runtime-endpoint unix:///run/containerd/containerd.sock"
          "--disable metrics-server"
          "--flannel-backend=none"
          "--disable-network-policy"
          "--disable servicelb"
          "--disable kube-proxy"
          "--disable traefik"
          "--disable local-storage"
          "--node-label bgp-enabled=\"true\""
          # "--debug"
        ];

        autoDeployCharts.cilium = {
          name = "cilium";
          repo = "https://helm.cilium.io";
          version = "1.19.0";
          hash = "sha256-W3dPDguTrXEnFmzawbrFtktbmsZgy6SrA2O5rH9Vo34=";
          values = {
            routingMode = "native";
            ipv4NativeRoutingCIDR = "10.42.0.0/16";
            # this need to be a host..
            k8sServiceHost = "127.0.0.1";
            k8sServicePort = 6443;
            autoDirectNodeRoutes =  true;
            kubeProxyReplacement =  true;
            ipam = {
              mode = "kubernetes";
              operator = {
                clusterPoolIPv4PodCIDRList = ["10.42.0.0/16"];
              };
            };
            operator.replicas =  1;
          };
        };

        manifests.fluxoperator.source = ../../manifests/flux-operator.yaml;
        manifests.fluxinstance.content = {
          apiVersion = "fluxcd.controlplane.io/v1";
          kind = "FluxInstance";

          metadata = {
            name = "flux";
            namespace = "flux-system";
            annotations = {
              "fluxcd.controlplane.io/reconcileEvery" = "1h";
              "fluxcd.controlplane.io/reconcileTimeout" = "5m";
            };
          };

          spec = {
            distribution = {
              version = "2.x";
              registry = "ghcr.io/fluxcd";
              artifact = "oci://ghcr.io/controlplaneio-fluxcd/flux-operator-manifests";
            };

            components = [
              "source-controller"
              "kustomize-controller"
              "helm-controller"
              "notification-controller"
              "image-reflector-controller"
              "image-automation-controller"
            ];

            cluster = {
              type = "kubernetes";
              size = "medium";
              multitenant = false;
              networkPolicy = true;
              domain = "cluster.local";
            };

            kustomize = {
              patches = [
                {
                  target = { kind = "Deployment"; };
                  patch = ''
            - op: replace
              path: /spec/template/spec/nodeSelector
              value:
                kubernetes.io/os: linux
            - op: add
              path: /spec/template/spec/tolerations
              value:
                - key: "CriticalAddonsOnly"
                  operator: "Exists"
          '';
                }
              ];
            };

            sync = {
              kind = "GitRepository";
              url = "https://github.com/ph/heyklab.git";
              ref = "refs/heads/main";
              path = "clusters/";
              interval = "1m";
              pullSecret = "github-token";
            };
          };
        };
      }

      (lib.mkIf (cfg.mainServer != "" && !cfg.primary) {
        serverAddr = "https://${cfg.mainServer}:6443";
      })
    ];
  };
}
