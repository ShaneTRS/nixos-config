# VirtualBox (1.2)
{
  machine,
  lib,
  ...
}: let
  inherit (lib) mkForce;
in {
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
  users.users.${machine.user} = {
    hashedPassword = "$y$jET$N7MIfVqgEUh3jVxAi6cwB0$x7AbQ95awn0HjsS8csB2JRWXm98Pdg28zp.6dfmKmT/";
    hashedPasswordFile = null;
  };
  shanetrs.remote = {
    usb = {
      devices = "/sys/bus/pci/devices/0000:00:06.0/usb2/";
      ports = ["2-1"];
    };
  };
  # boot.kernelPackages = pkgs.linuxPackages_6_11;
  # shanetrs.hardware = {
  #   enable = true;
  #   graphics = "virtualbox";
  # };
  virtualisation.containers.cdi.dynamic.nvidia.enable = mkForce false;
  # user.home.packages = with pkgs; [ shanetrs.nix-software-center gtk3 ];
}
