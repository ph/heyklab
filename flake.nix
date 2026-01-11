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
  };

  outputs =
    { self, disko, nixpkgs, nixos-facter-modules, comin, ... }@inputs:
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

      forAllSystems = forSystems supportedSystems;

      domain = "cluster.heyk.internal";

      k8sMachines = [
        { hostName = "k1"; ip = "10.10.2.1"; }
        { hostName = "k2"; ip = "10.10.2.3"; }
        { hostName = "k3"; ip = "10.10.2.2"; }
      ];

      kubernetes = { hostName, ip }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./hosts/knode
            disko.nixosModules.disko
            ./modules/partitions/single-disk-zfs-swap.nix
            { hardware.facter.reportPath = ./hosts/knode/${hostName}.json; }
            {
              networking.hostName = hostName;
              networking = {
                interfaces.ens18 = {
                  ipv4.addresses = [{
                    address = ip;
                    prefixLength = 24;
                  }];
                };
                defaultGateway = {
                  address = "10.10.0.1";
                  interface = "ens18";
                };
              };
            }
            comin.nixosModules.comin
            ({
              services.comin = {
                enable = true;
                remotes = [{
                  name = "origin";
                  url = "https://github.com/ph/heyklab.git";
                }];
              };
            })
          ];
        };
    in
    {
      # 10.10.236.122
      # 10.10.179.116
      # 10.10.151.129
        
      # Machines
      # - leviathan
      # - neferu
      # - nimue
      nixosConfigurations.k1 = kubernetes { hostName = "k1"; ip = "10.10.2.1"; };
      nixosConfigurations.k2 = kubernetes { hostName = "k2"; ip = "10.10.2.2"; };
      nixosConfigurations.k3 = kubernetes { hostName = "k3"; ip = "10.10.2.3"; };

      # Minimal Bootable ISO
      packages = forAllSystems (
        { pkgs,  ... }:
        {
          # Create image to boot for supervisors like proxmox.
          vm-installer = (nixpkgs.lib.nixosSystem {
            inherit pkgs;

            modules = [
              "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
              { isoImage.edition = nixpkgs.lib.mkForce "vm-installer"; }
              ./modules/images/vm-boot.nix
            ];
          }).config.system.build.image;

          # Create image to boot on baremetal.
          usb-installer = (nixpkgs.lib.nixosSystem {
            inherit pkgs;

            modules = [
              "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
              { isoImage.edition = nixpkgs.lib.mkForce "usb-installer"; }
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
            ];
          };
        }
      );
    };
}
# nix --extra-experimental-features nix-command --extra-experimental-features flakes run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-facter ./hosts/knode/k1.json  --flake .#k1 --target-host deploy@10.10.236.122
