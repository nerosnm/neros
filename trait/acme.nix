{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.acme;
in
{
  options = {
    cacti.acme = {
      enable = mkEnableOption "Acme";
    };
  };

  config = mkIf cfg.enable {
    security.acme = {
      acceptTerms = true;
      defaults = {
        email = "soren@neros.dev";
        webroot = "/var/lib/acme/acme-challenge";
      };
    };
  };
}
