# VirtualBox (1.2)
{
  config,
  lib,
  ...
}: let
  inherit (lib) mkForce;
in {
  shanetrs.remote = {
    usb = {
      devices = "/sys/bus/pci/devices/0000:00:06.0/usb2/";
      ports = ["2-1"];
    };
    # hardware = {
    #   enable = true;
    #   gpu = "virtualbox";
    # };
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/ROOT";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
    };
  };
  swapDevices = [];
  users.users.${config.tundra.user} = {
    hashedPassword = "$y$jET$N7MIfVqgEUh3jVxAi6cwB0$x7AbQ95awn0HjsS8csB2JRWXm98Pdg28zp.6dfmKmT/";
    hashedPasswordFile = null;
  };
  # boot.kernelPackages = pkgs.linuxPackages_6_11;
  hardware.nvidia-container-toolkit.enable = mkForce false;

  tundra.user = "shane";
}
