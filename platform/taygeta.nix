{ config
, modulesPath
, ...
}:

let
  soren = builtins.readFile ../keys/soren.pub;
in
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  networking = {
    hostName = "taygeta";

    firewall = {
      enable = true;

      # Expose the SSH port to the public internet
      allowedTCPPorts = [ 22 ];
    };
  };

  # Enable the OpenSSH server and allow both keys to authenticate with `root`.
  services.openssh = {
    enable = true;
    permitRootLogin = "prohibit-password";
  };

  users.users.root.openssh.authorizedKeys.keys = [ soren ];

  services.nginx = {
    virtualHosts = {
      "\"\"" = {
        default = true;
        rejectSSL = true;
        locations."/" = {
          return = "418";
        };
      };
    };
  };

  time.timeZone = "Europe/London";

  boot = {
    cleanTmpDir = true;
    loader.grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };

    initrd.kernelModules = [ "nvme" ];
  };

  fileSystems."/" = { device = "/dev/vda1"; fsType = "ext4"; };
  fileSystems."/boot" = { device = "/dev/disk/by-uuid/3A52-0EBB"; fsType = "vfat"; };

  system.stateVersion = "22.05";
}
