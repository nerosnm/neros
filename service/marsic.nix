{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services.marsic;
in
{
  options = {
    cacti.services.marsic = {
      enable = mkEnableOption "Activate the Marsic Minecraft server on this host";

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
        default = 2048;
        example = 3072;
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.cacti.services.enable;
        message = "Cacti services must be enabled to run Marsic";
      }
    ];

    users.users.minecraft = {
      description = "Marsic Minecraft server service user";
      home = "/srv/cacti/marsic";
      createHome = true;
      isSystemUser = true;
      group = "cacti";
      extraGroups = [ "keys" ];
    };

    systemd.services.marsic = {
      description = "Marsic Minecraft Server Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.papermc}/bin/minecraft-server -Xms${toString cfg.memory}M -Xmx${toString cfg.memory}M";
        Restart = "always";
        User = "minecraft";
        WorkingDirectory = "/srv/cacti/marsic";
      };

      path = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnutar
        pkgs.gzip
      ];
    };

    networking.firewall = {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [ cfg.port ];
    };

    environment.systemPackages =
      let
        backup = pkgs.writeShellScriptBin "backup-marsic" ''
          ${pkgs.coreutils}/bin/mkdir -p /srv/cacti/marsic/backups
          ${pkgs.gnutar}/bin/tar -cvpzf /srv/cacti/marsic/backups/marsic-$(date +%F-%H-%M).tar.gz /srv/cacti/marsic/marsic{,_nether,_the_end}

          # Delete older backups
          ${pkgs.findutils}/bin/find /srv/cacti/marsic/backups/ -type f -mtime +3 -name '*.gz' -delete
        '';
      in
      [
        backup
      ];
  };
}
