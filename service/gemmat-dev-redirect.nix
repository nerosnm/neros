{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services.gemmat-dev-redirect;
in
{
  options = {
    cacti.services.gemmat-dev-redirect = {
      enable = mkEnableOption "redirect gemmat.dev to Neocities";
    };
  };

  config = mkIf cfg.enable {
    # Expose the HTTP and HTTPS ports to the public internet
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    security.acme.certs."gemmat.dev".email = "gemtipper@gmail.com";

    services.nginx = {
      enable = true;

      virtualHosts = {
        "gemmat.dev" = {
          enableACME = true;
          forceSSL = true;

          locations."/" = {
            return = "301 $scheme://ninthroad.neocities.org$request_uri";
          };
        };
      };
    };
  };
}
