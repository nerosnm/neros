{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.services;
in
{
  options = {
    cacti.services = {
      enable = mkEnableOption "cacti group and /srv/cacti directory for cacti services";
    };
  };

  config = mkIf cfg.enable {
    users.groups.cacti = { };

    systemd.services.cacti-homedir-setup = {
      description = "Creates homedirs for /srv/cacti services";
      wantedBy = [ "multi-user.target" ];

      serviceConfig.Type = "oneshot";

      script = with pkgs; ''
        ${coreutils}/bin/mkdir -p /srv/cacti
        ${coreutils}/bin/chown root:cacti /srv/cacti
        ${coreutils}/bin/chmod 775 /srv/cacti
      '';
    };
  };
}
