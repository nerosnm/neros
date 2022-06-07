{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services.hatysa;
  secret = config.nerosnm.secrets.hatysa;
in
{
  options = {
    cacti.services.hatysa = {
      enable = mkEnableOption "Activate the Hatysa Discord bot";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.cacti.services.enable;
        message = "Cacti services must be enabled to run Hatysa";
      }
    ];

    users.users.hatysa = {
      createHome = true;
      description = "github.com/nerosnm/hatysa";
      isSystemUser = true;
      group = "cacti";
      home = "/srv/cacti/hatysa";
      extraGroups = [ "keys" ];
    };

    cacti.secrets.hatysa-discord-token = {
      value = secret.discordToken;
      dest = "/srv/cacti/hatysa/discord-token";
      owner = "hatysa";
      group = "cacti";
      permissions = "0400";
    };

    systemd.services.hatysa = {
      wantedBy = [ "multi-user.target" ];
      after = [ "hatysa-discord-token-key.service" ];
      wants = [ "hatysa-discord-token-key.service" ];

      serviceConfig = {
        User = "hatysa";
        Group = "cacti";
        Restart = "on-failure";
        WorkingDirectory = "/srv/cacti/hatysa";
        RestartSec = "30s";
      };

      script = ''
        export DISCORD_TOKEN=$(cat ./discord-token)
        export HATYSA_PREFIX=","
        export RUST_LOG="info,hatysa=debug"
        ${pkgs.hatysa}/bin/hatysa
      '';
    };
  };
}
