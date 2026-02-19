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
      "iscsi_tcp"
      "nbd"
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
      openiscsi
    ];
    
    networking.nftables.enable = false;
    networking.firewall = {
      checkReversePath = false;
      trustedInterfaces = [ "cni+" ];
      allowedTCPPorts = [
        4240 # cilium
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

    # See workaround here: https://github.com/longhorn/longhorn/issues/2166#issuecomment-3094699127
    services.openiscsi = {
      enable = true;
      name = "${config.networking.hostName}-initiatorhost";
    };
    systemd.services.iscsid.serviceConfig = {
      PrivateMounts = "yes";
      BindPaths = "/run/current-system/sw/bin:/bin";
    };
    systemd.tmpfiles.rules = [
      "L /usr/bin/mount - - - - /run/current-system/sw/bin/mount"
    ];

    # TODO needed?
    services.multipath.enable = false;

    services.k3s = lib.mkMerge [
      {
        enable = false;
        role = "server";
        clusterInit = cfg.primary;
        extraFlags = [
          "--token-file ${cfg.tokenPath}"
          "--disable=metrics-server"
          "--flannel-backend=none"
          "--disable-network-policy"
          "--disable=servicelb"
          "--disable-kube-proxy"
          "--disable=traefik"
          "--disable=local-storage"
          # "--debug"
        ];
      }
      (lib.mkIf (cfg.mainServer != "" && cfg.primary) {
        manifests.cilium.content = {
          apiVersion = "helm.cattle.io/v1";
          kind = "HelmChart";
          metadata = {
            name = "cilium";
            namespace = "kube-system";
          };
          spec = {
            bootstrap = true;
            targetNamespace = "kube-system";
            createNamespace = false;
            repo = "https://helm.cilium.io";
            chart = "cilium";
            version = "1.19.0";
            valuesContent = ''
              encryption:
                enabled: true
                type: "wireguard"
                # This doesn't work on control-plane, there are excluded by default.
                nodeEncryption: true
              crds:
                install: true
              bgpControlPlane:
                enabled: true
              k8sServiceHost: "127.0.0.1"
              k8sServicePort: 6443
              kubeProxyReplacement: true
              gatewayAPI:
                enabled: true
              envoy:
                enabled: true
              routingMode: "native"
              ipv4NativeRoutingCIDR: "10.42.0.0/16"
              autoDirectNodeRoutes: true
              ingressController:
                enabled: true 
                loadbalancerMode: shared
              ipam:
                mode: "kubernetes"
                operator:
                  clusterPoolIPv4PodCIDRList: ["10.42.0.0/16"]
              operator:
                replicas: 3
            '';
          };
        };

        manifests.ciliumbgp.source = ../../manifests/cilium-bgp.yaml;

        # Cilium API Gateway
        # https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#prerequisites
        # manifests.gatewayclass.source = ../../manifests/gateway-api/gateway.networking.k8s.io_gatewayclasses.yaml;
        # manifests.gateways.source = ../../manifests/gateway-api/gateway.networking.k8s.io_gateways.yaml;
        # manifests.grpcroutes.source = ../../manifests/gateway-api/gateway.networking.k8s.io_grpcroutes.yaml;
        # manifests.httproutes.source = ../../manifests/gateway-api/gateway.networking.k8s.io_httproutes.yaml;
        # manifests.referencegrants.source = ../../manifests/gateway-api/gateway.networking.k8s.io_referencegrants.yaml;
        # manifests.tlsorutes.source = ../../manifests/gateway-api/gateway.networking.k8s.io_tlsroutes.yaml;

        # manifests.certmanager.content = {
        #   apiVersion = "helm.cattle.io/v1";
        #   kind = "HelmChart";
        #   metadata = {
        #     name = "cert-manager";
        #     namespace = "kube-system";
        #   };
        #   spec = {
        #     targetNamespace = "cert-manager";
        #     createNamespace = true;
        #     repo = "https://charts.jetstack.io";
        #     chart = "cert-manager";
        #     version = "v1.19.2";
        #     set = {
        #       "config.apiVersion" = "controller.config.cert-manager.io/v1alpha1";
        #       "config.kind" = "ControllerConfiguration";
        #       "config.enableGatewayAPI" = "true";
        #     };
        #     valuesContent = ''
        #       crds:
        #         enabled: true
        #       extraArgs:
        #       - --dns01-recursive-nameservers-only
        #       - --dns01-recursive-nameservers=8.8.8.8:53
        #     '';
        #   };
        # };

      })
      {
        manifests.fluxoperator.source = ../../manifests/flux-operator.yaml;
        manifests.fluxinstance.content = {
          apiVersion = "fluxcd.controlplane.io/v1";
          kind = "FluxInstance";

          metadata = {
            name = "flux";
            namespace = "flux-system";
            annotations = {
              "fluxcd.controlplane.io/reconcileEvery" = "5m";
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
              path = "clusters/production";
              interval = "1m";
              pullSecret = "github-token";
            };
          };
        };

        # manifests.cert-manager-configuration.content = {
        #   apiVersion = "cert-manager.io/v1";
        #   kind = "ClusterIssuer";
        #   metadata = {
        #     name = "letsencrypt-issuer";
        #     namespace = "nginx";
        #   };
        #   spec = {
        #     acme = {
        #       server = "https://acme-v02.api.letsencrypt.org/directory";
        #       email = "ph@heykimo.com";
        #       privateKeySecretRef = {
        #         name = "letsencrypt-issuer";
        #       };
        #       solvers = [
        #         {
        #           dns01 = {
        #             cloudDNS = {
        #               hostedZoneName = "heyk-org";
        #               project = "homelab-408320";
        #               serviceAccountSecretRef = {
        #                 name = "google-dns-key";
        #                 key = "key.json";
        #               };
        #             };
        #           };
        #         }
        #       ];
        #     };
        #   };
        # };
        
        # manifests.coredns-local.source = ../../manifests/coredns-local.yaml;
        # manifests.coredns-local-export-ip.content = {
        #   apiVersion = "v1";
        #   kind = "Service";
        #   metadata = {
        #     name = "coredns";
        #     namespace = "kube-system";
        #   };
        #   spec = {
        #     selector = {
        #       k8s-app = "kube-dns";
        #     };
        #     ports = [
        #       {
        #         protocol = "UDP";
        #         port = 53;
        #         targetPort = 53;
        #       }
        #     ];
        #     type = "LoadBalancer";
        #     loadBalancerIP = "10.10.20.53";
        #   };
        # };
      }

      (lib.mkIf (cfg.mainServer != "" && !cfg.primary) {
        serverAddr = "https://${cfg.mainServer}:6443";
      })
    ];
  };
}
