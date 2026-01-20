{ config, lib, ... }:
let
  cfg = config.custom.k8s;
in {
  options.k8s = {
    primary = lib.mkOption {
      type = lib.types.boolean;
      default = false;
    };
  };
  config = {
    services.k3s = {
      enable = true; 
      primary = cfg.primary;
    };
  };
}
