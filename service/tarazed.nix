{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services.tarazed;
in
{
  options = {
    cacti.services.tarazed = {
      enable = mkEnableOption "Activate the Tarazed Minecraft server on this host";

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
        default = 3072;
        example = 2048;
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.cacti.services.enable;
        message = "Cacti services must be enabled to run Tarazed";
      }
    ];

    users.users.minecraft = {
      description = "Tarazed Minecraft server service user";
      home = "/srv/cacti/tarazed";
      createHome = true;
      isSystemUser = true;
      group = "cacti";
      extraGroups = [ "keys" ];
    };

    systemd.services.tarazed = {
      description = "Tarazed Minecraft Server Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.jdk}/bin/java -Xms${toString cfg.memory}M -Xmx${toString cfg.memory}M @libraries/net/minecraftforge/forge/1.18.2-40.1.31/unix_args.txt nogui";
        Restart = "always";
        User = "minecraft";
        WorkingDirectory = "/srv/cacti/tarazed";
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [ cfg.port ];
    };
  };
}
