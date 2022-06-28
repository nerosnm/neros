{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services.cacti-dev;
in
{
  options = {
    cacti.services.cacti-dev = {
      enable = mkEnableOption "Activate the various webpages hosted under cacti.dev";
    };
  };

  config = mkIf cfg.enable {
    # Expose the HTTP and HTTPS ports to the public internet
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    security.acme.certs."cacti.dev".extraDomainNames = [
      "oxbow.cacti.dev"
    ];

    services.nginx = {
      enable = true;

      virtualHosts = {
        "cacti.dev" = {
          enableACME = true;
          forceSSL = true;

          locations."/" = {
            root = pkgs.cacti-dev.out;
          };
        };

        "oxbow.cacti.dev" = {
          forceSSL = true;
          useACMEHost = "cacti.dev";

          locations."/" = {
            root = pkgs.oxbow-cacti-dev.out;
          };
        };
      };
    };
  };
}
