{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services.neros-dev;
  secret = config.nerosnm.secrets.neros-dev;
in
{
  options = {
    cacti.services.neros-dev = {
      enable = mkEnableOption "Activate the various webpages hosted under neros.dev";

      port = mkOption rec {
        description = ''
          Port for neros.dev
        '';
        type = types.int;
        default = 3000;
        example = default;
      };
    };
  };

  config = mkIf cfg.enable {
    # Expose the HTTP and HTTPS ports to the public internet
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services.nginx = {
      enable = true;

      virtualHosts."neros.dev" = {
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
          proxyWebsockets = true;
        };
      };
    };

    users.users.neros = {
      createHome = true;
      description = "github.com/nerosnm/neros.dev";
      isSystemUser = true;
      group = "cacti";
      home = "/srv/cacti/neros";
      extraGroups = [ "keys" ];
    };

    cacti.secrets.neros-dev-honeycomb-key = {
      value = secret.honeycombApiKey;
      dest = "/srv/cacti/neros/honeycomb-api-key";
      owner = "neros";
      group = "cacti";
      permissions = "0400";
    };

    systemd.services.neros-dev = {
      wantedBy = [ "multi-user.target" ];
      after = [ ];
      wants = [ ];

      serviceConfig = {
        User = "neros";
        Group = "cacti";
        Restart = "on-failure";
        WorkingDirectory = "/srv/cacti/neros";
        RestartSec = "30s";
      };

      script = ''
        export PORT=${toString cfg.port}
        export RUST_LOG="neros_dev=info"
        export HONEYCOMB_API_KEY=$(cat ./honeycomb-api-key)
        export CONTENT_PATH=${pkgs.neros-dev-content}
        export STATIC_PATH=${pkgs.neros-dev-static}
        export STYLESHEET_PATH=${pkgs.neros-dev-stylesheet}/style.css
        ${pkgs.neros-dev}/bin/neros-dev
      '';
    };
  };
}
