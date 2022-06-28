{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services.tempo;

  home = "/srv/tempo";
  settingsFormat = pkgs.formats.yaml { };
in
{
  options = {
    cacti.services.tempo = {
      enable = mkEnableOption "Activate Tempo";

      port = mkOption rec {
        description = ''
          HTTP listen port for Tempo
        '';
        type = types.int;
        default = 9005;
        example = default;
      };

      grpcPort = mkOption rec {
        description = ''
          gRPC listen port for Tempo
        '';
        type = types.int;
        default = 9006;
        example = default;
      };

      otlpReceiverPort = mkOption rec {
        description = ''
          Port for the Tempo OTLP receiver
        '';
        type = types.int;
        default = 4317;
        example = default;
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ tempo ];

    systemd.services.tempo =
      let
        overrides = {
          overrides = {
            "\"single-tenant\"" = {
              search_tags_allow_list = [
                "instance"
              ];
              ingestion_rate_strategy = "local";
              ingestion_rate_limit_bytes = 15000000;
              ingestion_burst_size_bytes = 20000000;
              max_traces_per_user = 10000;
              max_global_traces_per_user = 0;
              max_bytes_per_trace = 50000;
              max_search_bytes_per_trace = 0;
              max_bytes_per_tag_values_query = 5000000;
              block_retention = "0s";
            };
          };
        };

        settings = {
          server = {
            http_listen_port = cfg.port;
            grpc_listen_port = cfg.grpcPort;
          };
          distributor = {
            receivers = {
              otlp = {
                protocols = {
                  grpc = {
                    endpoint = "0.0.0.0:${toString cfg.otlpReceiverPort}";
                  };
                };
              };
            };
          };

          ingester = {
            trace_idle_period = "10s";
            max_block_bytes = 100000;
            max_block_duration = "1m";
          };

          compactor = {
            compaction = {
              compaction_window = "1h";
              max_block_bytes = 100000000;
              block_retention = "1h";
              compacted_block_retention = "10m";
            };
          };

          storage = {
            trace = {
              backend = "local";
              block = {
                bloom_filter_false_positive = .05;
                index_downsample_bytes = 1000;
                encoding = "zstd";
              };
              wal = {
                path = "/tmp/tempo/wal";
                encoding = "snappy";
              };
              local = {
                path = "/tmp/tempo/blocks";
              };
              pool = {
                max_workers = 100;
                queue_depth = 10000;
              };
            };
          };
        };
      in
      {
        description = "Grafana Tempo Service Daemon";
        wantedBy = [ "multi-user.target" ];

        serviceConfig =
          let
            conf = settingsFormat.generate "config.yaml" settings;
          in
          {
            ExecStart = "${pkgs.tempo}/bin/tempo --config.file=${conf}";
            User = "tempo";
            Restart = "always";
            ProtectSystem = "full";
            DevicePolicy = "closed";
            NoNewPrivileges = true;
            WorkingDirectory = home;
            StateDirectory = "tempo";
          };
      };

    users.users.tempo = {
      createHome = true;
      group = "tempo";
      description = "Grafana Tempo";
      isSystemUser = true;
      inherit home;
    };
    users.groups.tempo = { };
  };
}
