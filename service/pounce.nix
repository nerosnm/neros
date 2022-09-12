{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services.pounce;
in
{
  options = {
    cacti.services.pounce = {
      enable = mkEnableOption "pounce IRC bouncer";
    };
  };

  config = mkIf cfg.enable { };

  security.acme.certs = {
    "irc.cacti.dev" = { };
  };
}
