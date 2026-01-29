{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      disko,
      nixpkgs,
      nixos-facter-modules,
      comin,
      sops-nix,
      ...
    }@inputs:
    let
      supportedSystems = [
        "x86_64-linux"
      ];

      forSystems =
        s: f:
        inputs.nixpkgs.lib.genAttrs s (
          system:
          f rec {
            inherit system;
            pkgs = import inputs.nixpkgs {
              inherit system;
            };
          }
        );

      k = { hostName, ip, primary ? false }: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./hosts/knode
          sops-nix.nixosModules.sops
          {
            sops = {
              defaultSopsFile = ./secrets/k8s.yaml;
              age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
              secrets.token = {
                path = "/run/secrets/token";
                restartUnits = [ "k3s.service" ];
              };

              # Expose github token for FluxCD
              secrets.github_token = {};
              templates.github_token = {
                content = builtins.toJSON {
                  apiVersion = "v1";
                  kind = "Secret";
                  metadata.name = "github_token";
                  stringData.github_token = sops-nix.nixosModules.sops.placeholder.github_token;
                  path = "/var/lib/rancher/k3s/server/manifests/github_token.json";
                };
              };
            };
          }
          {
            custom.k8s = {
              tokenPath = "/run/secrets/token";
              primary = primary; 
              mainServer = "10.10.0.11";
            };
          }
          disko.nixosModules.disko
          ./modules/partitions/single-disk-zfs-swap.nix
          { hardware.facter.reportPath = ./hosts/knode/facter.json; }
          {
            networking = {
              dhcpcd.enable = false;
              hostName = hostName;
              interfaces.ens18.ipv4.addresses = [{
                address = ip;
                prefixLength = 24;
              }];
              defaultGateway = { address = "10.10.0.1"; interface = "ens18"; };
              nameservers = ["8.8.8.8"];
            };
          }
          comin.nixosModules.comin
          ({
            services.comin = {
              debug = true;
              enable = true;
              remotes = [
                {
                  name = "origin";
                  url = "https://github.com/ph/heyklab.git";
                }
              ];
            };
          })
        ];
      };

      forAllSystems = forSystems supportedSystems;
    in
    {
      # Machines
      # - leviathan
      # - neferu
      # - nimue


      nixosConfigurations.k1 = k { hostName = "k1"; ip = "10.10.0.11"; primary = true; };
      nixosConfigurations.k2 = k { hostName = "k2"; ip = "10.10.0.12"; };
      nixosConfigurations.k3 = k { hostName = "k3"; ip = "10.10.0.13"; };

      # Minimal Bootable ISO
      packages = forAllSystems (
        { pkgs, ... }:
        {
          # Create image to boot for supervisors like proxmox.
          vm-installer =
            (nixpkgs.lib.nixosSystem {
              inherit pkgs;

              modules = [
                "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
                ./modules/images/vm-boot.nix
              ];
            }).config.system.build.image;

          # Create image to boot on baremetal.
          usb-installer =
            (nixpkgs.lib.nixosSystem {
              inherit pkgs;

              modules = [
                "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
                ./modules/images/usb-boot.nix
              ];
            }).config.system.build.image;
        }
      );

      # Dev
      devShells = forAllSystems (
        { pkgs, system }:
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nil
              age
              jq
              kubectl
              ssh-to-age
            ] ++ [ pkgs.sops ];
          };
        }
      );

      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt-tree);
    };
}
# nix --extra-experimental-features nix-command --extra-experimental-features flakes run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-facter ./hosts/knode/facter.json  --flake .#knode-bootstrap --target-host deploy@10.10.229.88
#
# nix run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-facter ./hosts/knode/k1.json  --flake .#k1 --target-host deploy@10.10.229.88
