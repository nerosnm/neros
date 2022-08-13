{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services.datadog;

  secret = config.nerosnm.secrets.datadog;

  home = "/srv/datadog";
in
{
  options = {
    cacti.services.datadog = {
      enable = mkEnableOption "Datadog agent";

      hostname = mkOption rec {
        description = ''
          Datadog agent hostname
        '';
        type = types.str;
        example = "taygeta";
      };
    };
  };

  config = mkIf cfg.enable {
    cacti.secrets.datadog-api-key = {
      value = secret.apiKey;
      dest = "${home}/apiKey";
      owner = "datadog";
      group = "datadog";
      permissions = "0400";
    };

    services.datadog-agent = {
      inherit (cfg) enable hostname;
      apiKeyFile = "${home}/apiKey";
      site = "datadoghq.eu";
    };
  };
}
