{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services.oxbow;
  secret = config.nerosnm.secrets.oxbow;
in
{
  options = {
    cacti.services.oxbow = {
      enable = mkEnableOption "Activate the oxbow Twitch chat bot";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.cacti.services.enable;
        message = "Cacti services must be enabled to run Oxbow";
      }
    ];

    users.users.oxbow = {
      createHome = true;
      description = "github.com/nerosnm/oxbow";
      isSystemUser = true;
      group = "cacti";
      home = "/srv/cacti/oxbow";
      extraGroups = [ "keys" ];
    };

    cacti.secrets.oxbow-client-id = {
      value = secret.clientID;
      dest = "/srv/cacti/oxbow/client-id";
      owner = "oxbow";
      group = "cacti";
      permissions = "0400";
    };

    cacti.secrets.oxbow-client-secret = {
      value = secret.clientSecret;
      dest = "/srv/cacti/oxbow/client-secret";
      owner = "oxbow";
      group = "cacti";
      permissions = "0400";
    };

    systemd.services.oxbow = {
      wantedBy = [ "multi-user.target" ];
      after = [ "oxbow-client-id-key.service" "oxbow-client-secret-key.service" ];
      wants = [ "oxbow-client-id-key.service" "oxbow-client-secret-key.service" ];

      serviceConfig = {
        User = "oxbow";
        Group = "cacti";
        Restart = "on-failure";
        WorkingDirectory = "/srv/cacti/oxbow";
        RestartSec = "30s";
      };

      script = ''
        export CLIENT_ID=$(cat ./client-id)
        export CLIENT_SECRET=$(cat ./client-secret)
        export TWITCH_NAME="oxoboxowot"
        export DATABASE=./oxbow.sqlite3
        export RUST_LOG="info,oxbow=debug"
        ${pkgs.oxbow}/bin/oxbow --channels nerosnm stuck_overflow ninthroads fisken_ai exodiquas theidofalan
      '';
    };
  };
}
