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

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self,
      disko,
      nixpkgs,
      nixos-facter-modules,
      comin,
      agenix,
      ... }@inputs:
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
    in
      {
        # Machines
        # - leviathan
        # - neferu
        # - nimue
        nixosConfigurations.k1 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./hosts/knode
            disko.nixosModules.disko
            ./modules/partitions/single-disk-zfs-swap.nix
            { hardware.facter.reportPath = ./hosts/knode/facter.json; }
            { networking.hostName = "k1"; }
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
            agenix.nixosModules.default
          ];
        };

        # Minimal Bootable ISO
        packages = forAllSystems (
          { pkgs,  ... }:
          {
            # Create image to boot for supervisors like proxmox.
            vm-installer = (nixpkgs.lib.nixosSystem {
              inherit pkgs;

              modules = [
                "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
                ./modules/images/vm-boot.nix
              ];
            }).config.system.build.image;

            # Create image to boot on baremetal.
            usb-installer = (nixpkgs.lib.nixosSystem {
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
                agenix
                jq
                kubectl
              ];
            };
          }
        );
      };
}
  # nix --extra-experimental-features nix-command --extra-experimental-features flakes run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-facter ./hosts/knode/facter.json  --flake .#knode-bootstrap --target-host deploy@10.10.229.88
