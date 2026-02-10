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

    # Secrets for Google DNS ACME.
    secrets.google-dns-key = { };
    templates.google-dns-key = {
      content = builtins.toJSON {
        apiVersion = "v1";
        kind = "Secret";
        metadata = {
         name = "key.json"; 
         namespace = "cert-manager";
        };

        stringData = config.sops.placeholder.google-dns-key;
      };
      path = "/var/lib/rancher/k3s/server/manifests/google-dns-key.json";
    };
  };
}
