{ config
, lib
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
    hostName = "tarazed";

    useDHCP = false;
    interfaces.ens3.useDHCP = true;

    firewall = {
      enable = true;

      # Expose the SSH port to the public internet
      allowedTCPPorts = [ 22 ];
    };
  };

  # Enable the OpenSSH server and allow Søren's key to authenticate with `root`.
  services.openssh = {
    enable = true;
    permitRootLogin = "prohibit-password";
  };

  users.users.root.openssh.authorizedKeys.keys = [ soren ];

  time.timeZone = "Europe/London";

  boot = {
    loader.grub = {
      enable = true;
      version = 2;
      devices = [ "/dev/sda" ];
    };
    initrd = {
      availableKernelModules = [ "ata_piix" "virtio_pci" "virtio_scsi" "xhci_pci" "sd_mod" "sr_mod" ];
      kernelModules = [ ];
    };
    kernelModules = [ ];
    extraModulePackages = [ ];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/59b3dbfa-61f0-4001-a157-70ad737147cf";
    fsType = "ext4";
  };

  swapDevices = [ ];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  system.stateVersion = "21.11";
}
