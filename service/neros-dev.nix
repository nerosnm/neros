{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services.neros-dev;
in
{
  options = {
    cacti.services.neros-dev = {
      enable = mkEnableOption "Activate the various webpages hosted under neros.dev";

      wip = {
        enable = mkEnableOption "Enable wip.neros.dev";
      };
    };
  };

  config = mkIf cfg.enable {
    # Expose the HTTP and HTTPS ports to the public internet
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    security.acme = {
      acceptTerms = true;
      defaults.email = "soren@neros.dev";

      certs."neros.dev".extraDomainNames = [
      ] ++ optionals cfg.wip.enable [
        "wip.neros.dev"
      ];
    };

    services.nginx = {
      enable = true;

      virtualHosts = {
        "neros.dev" = {
          enableACME = true;
          forceSSL = true;

          locations."/" = {
            root = pkgs.neros-dev.out;
          };
        };

        "wip.neros.dev" = mkIf cfg.wip.enable {
          forceSSL = true;
          useACMEHost = "neros.dev";

          locations."/" = {
            root = pkgs.neros-dev-wip.out;
          };
        };
      };
    };
  };
}
