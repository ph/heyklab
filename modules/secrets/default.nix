{ config, ... }:
{
  sops = {
    secrets.github_token = { };
    templates.password = {
      content = builtins.toJSON {
        apiVersion = "v1";
        kind = "Secret";
        metadata.name = "password";
        stringData.github_token = config.sops.placeholder.github_token;
      };
      path = "/var/lib/rancher/k3s/server/manifests/github_token.json";
    };
  };
}
