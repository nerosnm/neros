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

  config =
    let
      external-port = 6697;
      calico-port = 6969;
    in
    mkIf cfg.enable {
      age.secrets."pounce-auth.pem" = {
        file = ../secrets/pounce-auth.pem.age;
        owner = "pounce";
        group = "pounce";
      };

      age.secrets."pounce-client.pem" = {
        file = ../secrets/pounce-client.pem.age;
        owner = "pounce";
        group = "pounce";
      };

      environment.etc."xdg/pounce/defaults".text = ''
        local-ca = ${config.age.secrets."pounce-auth.pem".path}
        local-path = /srv/pounce
      '';

      environment.etc."xdg/pounce/libera".text = ''
        local-cert = /var/lib/acme/libera.cacti.dev/fullchain.pem
        local-priv = /var/lib/acme/libera.cacti.dev/key.pem

        local-host = libera.cacti.dev
        host = irc.eu.libera.chat

        client-cert = ${config.age.secrets."pounce-client.pem".path}
        client-priv = ${config.age.secrets."pounce-client.pem".path}
        sasl-external

        nick = nerosnm
        real = søren
      '';

      users.groups.pounce = { };
      users.users.pounce = {
        description = "Pounce IRC bouncer user";
        home = "/srv/pounce";
        createHome = true;
        isSystemUser = true;
        group = "pounce";
        extraGroups = [ "keys" "nginx" ];
      };

      systemd.services.pounce-libera = {
        description = "Pounce IRC Bouncer Service (Libera)";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
          "acme-libera.cacti.dev.service"
        ];

        serviceConfig = {
          ExecStart = "${pkgs.pounce}/bin/pounce defaults libera";
          Restart = "always";
          User = "pounce";
          WorkingDirectory = "/srv/pounce";
        };
      };

      systemd.services.calico = {
        description = "Calico IRC Dispatcher";
        wantedBy = [ "multi-user.target" ];
        after = [
          "pounce-libera.service"
        ];

        serviceConfig = {
          ExecStart = ''
            ${pkgs.pounce}/bin/calico \
              -P ${toString calico-port} \
              /srv/pounce
          '';
          Restart = "no";
          User = "pounce";
          WorkingDirectory = "/srv/pounce";
        };
      };

      networking.firewall.allowedTCPPorts = [ external-port ];

      services.nginx = {
        enable = true;
        recommendedProxySettings = true;

        virtualHosts = {
          "libera.cacti.dev" = {
            forceSSL = true;
            enableACME = true;
          };
        };

        streamConfig = ''
          upstream calico {
            server 127.0.0.1:${toString calico-port};
          }

          server {
            listen ${toString external-port};
            listen [::0]:${toString external-port};

            proxy_pass calico;
          }
        '';
      };
    };
}
