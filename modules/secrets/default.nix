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
         name = "google-dns-key"; 
         namespace = "cert-manager";
        };

        data = {
          "key.json" = config.sops.placeholder.google-dns-key;
        };
      };
      path = "/var/lib/rancher/k3s/server/manifests/google-dns-key.json";
    };

    # Secrets for Garage
    secrets.garage-admin-token = { };
    templates.garage-admin-token = {
      content = builtins.toJSON {
        apiVersion = "v1";
        kind = "Secret";
        metadata = {
         name = "garage-admin-token"; 
         namespace = "default";
        };
        stringData = {
          token = config.sops.placeholder.garage-admin-token;
        };
      };
      path = "/var/lib/rancher/k3s/server/manifests/garage-admin-token.json";
    };

    # Secrets for Garage
    secrets.database-grafana-password = { };
    templates.database-grafana-password = {
      content = builtins.toJSON {
        apiVersion = "v1";
        kind = "Secret";
        metadata = {
         name = "database-grafana-password"; 
         namespace = "pg";
        };
        stringData = {
          username = "grafana";
          password = config.sops.placeholder.database-grafana-password;
        };
      };
      path = "/var/lib/rancher/k3s/server/manifests/database-grafana-password.json";
    };

    templates.database-grafana-password-monitoring = {
      content = builtins.toJSON {
        apiVersion = "v1";
        kind = "Secret";
        metadata = {
          name = "database-grafana-password"; 
          namespace = "monitoring";
        };
        stringData = {
          username = "grafana";
          password = config.sops.placeholder.database-grafana-password;
        };
      };
      path = "/var/lib/rancher/k3s/server/manifests/database-grafana-password-monitoring.json";
    };
 };
}
