{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti;

  secret = types.submodule {
    options = {
      value = mkOption {
        type = types.str;
        description = "Value of the secret";
      };

      dest = mkOption {
        type = types.str;
        description = "Where to write the decrypted secret to";
      };

      owner = mkOption {
        default = "root";
        type = types.str;
        description = "Who should own the secret";
      };

      group = mkOption {
        default = "root";
        type = types.str;
        description = "What group should own the secret";
      };

      permissions = mkOption {
        default = "0400";
        type = types.str;
        description = "Permissions expressed as octal";
      };
    };
  };

  mkSecretOnDisk = name: value:
    pkgs.stdenv.mkDerivation {
      name = "${name}-secret";
      phases = "installPhase";
      buildInputs = [ pkgs.rage ];
      installPhase = ''
        echo "${value}" | rage -a -r '${cfg.key}' -o "$out"
      '';
    };

  mkService = name:
    { value, dest, owner, group, permissions }: {
      description = "Decrypt secret for ${name}";
      wantedBy = [ "multi-user.target" ];

      serviceConfig.Type = "oneshot";

      script = ''
        rm -rf ${dest}
        "${pkgs.rage}"/bin/rage -d -i /etc/ssh/ssh_host_ed25519_key -o '${dest}' '${mkSecretOnDisk name value}'
        chown '${owner}':'${group}' '${dest}'
        chmod '${permissions}' '${dest}'
      '';
    };
in
{
  options.cacti = {
    key = mkOption {
      type = types.str;
      description = ''
        Public key of this host
      '';
    };

    secrets = mkOption {
      type = types.attrsOf secret;
      description = "Secret configuration";
      default = { };
    };
  };

  config = {
    systemd.services = mapAttrs'
      (name: info: {
        name = "${name}-key";
        value = (mkService name info);
      })
      cfg.secrets;
  };
}
