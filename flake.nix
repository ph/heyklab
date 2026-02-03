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

      k = { hostName, ip, primary ? false, diskPartition ? "/dev/sda", swapSize ? "8GB", eth }: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./hosts/knode
          sops-nix.nixosModules.sops
          {
            sops.defaultSopsFile = ./secrets/k8s.yaml;
            sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
            sops.secrets.token = {
              path = "/run/secrets/token";
              restartUnits = [ "k3s.service" ];
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
          {
           disko.devices.disk.x.device = diskPartition;
           disko.devices.zpool.zroot.datasets."root/swap".size = swapSize;
          }
          { hardware.facter.reportPath = ./hosts/knode/${hostName}.json; }
          {
            networking = {
              dhcpcd.enable = false;
              hostName = hostName;
              interfaces.${eth}.ipv4.addresses = [{
                address = ip;
                prefixLength = 24;
              }];
              defaultGateway = {
                address = "10.10.0.1";
                interface = eth;
              };
              nameservers = [
                "8.8.8.8"
                "1.1.1.1"
              ];
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
      nixosConfigurations.leviathan = k {
        hostName = "leviathan";
        ip = "10.10.0.11";
        primary = true;
        swapSize = "16GB";
        eth = "eno1";
      };

      nixosConfigurations.neferu = k {
        hostName = "neferu";
        ip = "10.10.0.12";
        diskPartition = "/dev/sdb";
        swapSize = "16GB";
        eth = "enp2s0";
      };

      nixosConfigurations.nimue = k {
        hostName = "nimue";
        ip = "10.10.0.13";
        swapSize = "8GB";
        eth = "eno1";
      };

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
