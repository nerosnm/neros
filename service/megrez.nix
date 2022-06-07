{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services.megrez;
in
{
  options = {
    cacti.services.megrez = {
      enable = mkEnableOption "Activate the Megrez Minecraft server on this host";

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
        message = "Cacti services must be enabled to run Megrez";
      }
    ];

    users.users.minecraft = {
      description = "Megrez Minecraft server service user";
      home = "/srv/cacti/megrez";
      createHome = true;
      isSystemUser = true;
      group = "cacti";
      extraGroups = [ "keys" ];
    };

    systemd.services.megrez = {
      description = "Megrez Minecraft Server Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.jdk}/bin/java -Xms${toString cfg.memory}M -Xmx${toString cfg.memory}M @libraries/net/minecraftforge/forge/1.18.2-40.0.44/unix_args.txt nogui";
        Restart = "always";
        User = "minecraft";
        WorkingDirectory = "/srv/cacti/megrez";
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [ cfg.port ];
    };
  };
}
