{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services.pomocop;
  secret = config.nerosnm.secrets.pomocop;
in
{
  options = {
    cacti.services.pomocop = {
      enable = mkEnableOption "Activate the pomocop Discord chat bot";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.cacti.services.enable;
        message = "Cacti services must be enabled to run Pomocop";
      }
    ];

    users.users.pomocop = {
      createHome = true;
      description = "github.com/nerosnm/pomocop";
      isSystemUser = true;
      group = "cacti";
      home = "/srv/cacti/pomocop";
      extraGroups = [ "keys" ];
    };

    cacti.secrets.pomocop-token = {
      value = secret.token;
      dest = "/srv/cacti/pomocop/token";
      owner = "pomocop";
      group = "cacti";
      permissions = "0400";
    };

    cacti.secrets.pomocop-application-id = {
      value = secret.applicationID;
      dest = "/srv/cacti/pomocop/application-id";
      owner = "pomocop";
      group = "cacti";
      permissions = "0400";
    };

    cacti.secrets.pomocop-owner-id = {
      value = secret.ownerID;
      dest = "/srv/cacti/pomocop/owner-id";
      owner = "pomocop";
      group = "cacti";
      permissions = "0400";
    };

    systemd.services.pomocop = {
      wantedBy = [ "multi-user.target" ];
      after = [ "pomocop-token.service" "pomocop-application-id.service" "pomocop-owner-id.service" ];
      wants = [ "pomocop-token.service" "pomocop-application-id.service" "pomocop-owner-id.service" ];

      serviceConfig = {
        User = "pomocop";
        Group = "cacti";
        Restart = "on-failure";
        WorkingDirectory = "/srv/cacti/pomocop";
        RestartSec = "30s";
      };

      script = ''
        export TOKEN=$(cat ./token)
        export APPLICATION_ID=$(cat ./application-id)
        export OWNER_ID=$(cat ./owner-id)
        export RUST_LOG="info,pomocop=debug"
        ${pkgs.pomocop}/bin/pomocop
      '';
    };
  };
}
