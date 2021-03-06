{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services.prometheus;

  home = "/srv/prometheus";
in
{
  options = {
    cacti.services.prometheus = {
      enable = mkEnableOption "Activate Prometheus";

      port = mkOption rec {
        description = ''
          Port to serve Prometheus over
        '';
        type = types.int;
        default = 9001;
        example = default;
      };

      nodeExporter = {
        enable = mkEnableOption "Activate the Prometheus node exporter";

        port = mkOption rec {
          description = ''
            Port to serve the Prometheus node exporter over
          '';
          type = types.int;
          default = 9002;
          example = default;
        };
      };
    };
  };

  config = {
    services.prometheus = {
      inherit (cfg) enable port;

      exporters = {
        node = {
          inherit (cfg.nodeExporter) enable port;
          enabledCollectors = [ "systemd" ];
        };
      };

      globalConfig = {
        scrape_interval = "15s";
      };

      scrapeConfigs = [
      ] ++ optionals cfg.enable [
        {
          job_name = "node";
          static_configs = [
            {
              targets = [ "taygeta:${toString cfg.nodeExporter.port}" ];
              labels = {
                host = "taygeta";
              };
            }
            {
              targets = [ "marsic:${toString cfg.nodeExporter.port}" ];
              labels = {
                host = "marsic";
              };
            }
            {
              targets = [ "syrma:${toString cfg.nodeExporter.port}" ];
              labels = {
                host = "syrma";
              };
            }
            {
              targets = [ "megrez:${toString cfg.nodeExporter.port}" ];
              labels = {
                host = "megrez";
              };
            }
            {
              targets = [ "tarazed:${toString cfg.nodeExporter.port}" ];
              labels = {
                host = "tarazed";
              };
            }
          ];
        }
        {
          job_name = "minecraft";
          static_configs = [
            {
              targets = [ "marsic:9225" ];
              labels = {
                server_name = "marsic";
              };
            }
            {
              targets = [ "syrma:19565" ];
              labels = {
                server_name = "syrma";
              };
            }
          ];
        }
      ];
    };
  };
}
