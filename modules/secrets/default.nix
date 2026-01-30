{ config, ... }:
{
  sops = {
    secrets.github-token = { };
    templates.password = {
      content = builtins.toJSON {
        apiVersion = "v1";
        kind = "Secret";
        metadata.name = "github-token";
        namespace = "flux-system";
        stringData.github_token = config.sops.placeholder.github-token;
      }udo
      path = "/var/lib/rancher/k3s/server/manifests/github-token.json";
    };
  };
}
