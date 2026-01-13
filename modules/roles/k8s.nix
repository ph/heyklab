{ config, lib, ... }:
{
  options.k8s = {
    primary = lib.mkOption {
      type = lib.types.boolean;
      default = false;
    };
  };

  config = {
    services.k3s.enable = true;
  };
}
