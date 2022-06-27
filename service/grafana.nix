{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services.grafana;
  promcfg = config.cacti.services.prometheus;
  lokicfg = config.cacti.services.loki;

  secret = config.nerosnm.secrets.grafana;

  home = "/srv/grafana";
in
{
  options = {
    cacti.services.grafana = {
      enable = mkEnableOption "Activate Grafana";

      port = mkOption rec {
        description = ''
          Port to serve Grafana interface over
        '';
        type = types.int;
        default = 2342;
        example = default;
      };
    };
  };

  config = mkIf cfg.enable {
    cacti.secrets.grafana-admin-password = {
      value = secret.adminPassword;
      dest = "${home}/admin-password";
      owner = "grafana";
      group = "grafana";
      permissions = "0400";
    };

    services.grafana = {
      inherit (cfg) enable port;

      domain = "grafana.cacti.dev";
      addr = "127.0.0.1";
      rootUrl = "%(protocol)s://%(domain)s/";

      dataDir = home;
      security.adminPasswordFile = "${home}/admin-password";

      provision = {
        enable = true;

        datasources = [
        ] ++ optional promcfg.enable {
          name = "Prometheus";
          type = "prometheus";
          url = "http://localhost:${toString promcfg.port}";
          jsonData = {
            scrape_interval = "15s";
          };
        } ++ optional lokicfg.enable {
          name = "Loki";
          type = "loki";
          url = "http://localhost:${toString lokicfg.port}";
        };
      };
    };

    security.acme.certs."cacti.dev".extraDomainNames = [
      "grafana.cacti.dev"
    ];

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;

      virtualHosts = {
        "grafana.cacti.dev" = {
          forceSSL = true;
          useACMEHost = "cacti.dev";

          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.port}";
            proxyWebsockets = true;
          };
        };
      };
    };
  };
}
