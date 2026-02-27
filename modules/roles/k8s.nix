{ config, lib, pkgs, ... }:
let
  cfg = config.custom.k8s;

  gw = pkgs.fetchFromGitHub {
    owner = "kubernetes-sigs";
    repo = "gateway-api";
    rev = "v.1.4.1";
    sha256 = "sha256-hash-of-tarball";
  };

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
      # Bootstrap of the Kubernetes cluster, to do this we are using K3S features that read the initial
      # manifests present in /var/lib/rancer/k3s/server/manifest and apply them, after the first sync when Cilium
      # and Flux are installed. Flux will takes over the configuration and maintenance of the cluster from
      # NixOS. 
      {
        manifests.gatewayclass.source = "${gw}/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml";
        manifests.gateways.source = "${gw}/config/crd/standard/gateway.networking.k8s.io_gateways.yaml";
        manifests.httproutes.source = "${gw}/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml";
        manifests.referencegrants.source = "${gw}/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml";
        manifests.grpcroutes.source = "${gw}/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml";
        manifests.backendtlspolicies.source = "${gw}/config/crd/standard/gateway.networking.k8s.io_backendtlspolicies.yaml";
        manifests.tlrsroutes.source = "${gw}/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml";

        manifests.flux-system-namespace.content = {
          apiVersion = "v1";
          kind = "Namespace";
          metadata = {
            name = "flux-system";
          };
        };

        autoDeployCharts.cilium = {
          name = "cilium";
          repo = "https://helm.cilium.io";
          version = "1.19.0";
          hash = "sha256-W3dPDguTrXEnFmzawbrFtktbmsZgy6SrA2O5rH9Vo34=";
          targetNamespace = "kube-system";
          values = ../../clusters/infrastructure/configs/helm-values-cilium.yaml;
          extraFieldDefinitions = {
            spec = {
              bootstrap = true;
            };
          };
        };

        autoDeployCharts.flux-operator = {
          name = "flux-operator";
          repo = "oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator";
          version = "0.42.1";
          hash = "sha256-X40JAypyrTc/cya4OVxAv+Ug1kMEZV4vKd+4wwyplXg=";
          targetNamespace = "flux-system";
        };

        # Load Flux configuration from our infrastructure configuration.
        manifests.flux-instrance-config.source = ../../clusters/infrastructure/configs/flux-instance.yaml;
      }

      (lib.mkIf (cfg.mainServer != "" && !cfg.primary) {
        serverAddr = "https://${cfg.mainServer}:6443";
      })
    ];
  };
}
