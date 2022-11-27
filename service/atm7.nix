{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services.atm7;
in
{
  options = {
    cacti.services.atm7 = {
      enable = mkEnableOption "Activate the All The Mods 7 Minecraft server on this host";

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
        message = "Cacti services must be enabled to run ATM7";
      }
    ];

    users.users.minecraft = {
      description = "All The Mods 7 Minecraft server service user";
      home = "/srv/cacti/atm7";
      createHome = true;
      isSystemUser = true;
      group = "cacti";
      extraGroups = [ "keys" ];
    };

    systemd.services.atm7 = {
      description = "All The Mods 7 Minecraft Server Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.jdk}/bin/java @user_jvm_args.txt -Xms${toString cfg.memory}M -Xmx${toString cfg.memory}M @user_jvm_args.txt @libraries/net/minecraftforge/forge/1.18.2-40.1.80/unix_args.txt nogui";
        Restart = "always";
        # RuntimeMaxSec = 86400; # 1 day
        User = "minecraft";
        WorkingDirectory = "/srv/cacti/atm7";
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [ cfg.port ];
    };
  };
}
