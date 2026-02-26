{ config, ... }:
{
  sops = {
    # Token for `comin` service to pull new nix config.
    secrets.github-token = { };
    templates.password = {
      content = builtins.toJSON {
        apiVersion = "v1";
        kind = "Secret";
        metadata = {
         name = "github-token"; 
         namespace = "flux-system";
        };
        stringData = {
          username = "ph";
          password = config.sops.placeholder.github-token;
        };
      };
      path = "/var/lib/rancher/k3s/server/manifests/github-token.json";
    };

    # Token for `comin` service to pull new nix config.
    secrets.sops-agekey = { };
    templates.sops-agekey = {
      content = builtins.toJSON {
        apiVersion = "v1";
        kind = "Secret";
        metadata = {
         name = "sops-agekey"; 
         namespace = "flux-system";
        };
        stringData = {
          "age.agekey" = config.sops.placeholder.sops-agekey;
        };
      };
      path = "/var/lib/rancher/k3s/server/manifests/sops-agekey.json";
    };
 };
}
