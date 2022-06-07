{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services.syrma;
in
{
  options = {
    cacti.services.syrma = {
      enable = mkEnableOption "Activate the Syrma Minecraft server on this host";

      port = mkOption {
        description = ''
          Port to expose the Minecraft server over. This must match the value in server.properties.
        '';
        type = types.int;
        default = 25565;
        example = 25569;
      };

      rconPort = mkOption {
        description = ''
          Port to connect to RCON through. This must match the value in server.properties.
        '';
        type = types.int;
        default = 25575;
        example = 25579;
      };

      memory = mkOption {
        description = ''
          How many MB of memory to dedicate to the server.
        '';
        type = types.int;
        default = 6144;
        example = 2048;
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.cacti.services.enable;
        message = "Cacti services must be enabled to run Syrma";
      }
    ];

    users.users.minecraft = {
      description = "Syrma Minecraft server service user";
      home = "/srv/cacti/syrma";
      createHome = true;
      isSystemUser = true;
      group = "cacti";
      extraGroups = [ "keys" ];
    };

    systemd.services.syrma = {
      description = "Syrma Minecraft Server Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.jre8}/bin/java -Xms${toString cfg.memory}M -Xmx${toString cfg.memory}M -jar forge-1.16.5-36.2.9.jar nogui";
        Restart = "always";
        RuntimeMaxSec = 86400; # 1 day
        User = "minecraft";
        WorkingDirectory = "/srv/cacti/syrma";
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [ cfg.port ];
    };
  };
}
