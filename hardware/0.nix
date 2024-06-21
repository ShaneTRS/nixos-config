# VirtualBox (1.2)
{ machine, pkgs, ... }: {
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
  swapDevices = [ ];
  users.users.${machine.user} = {
    hashedPassword = "$y$jET$N7MIfVqgEUh3jVxAi6cwB0$x7AbQ95awn0HjsS8csB2JRWXm98Pdg28zp.6dfmKmT/";
    hashedPasswordFile = null;
  };
  shanetrs.remote.enable = pkgs.lib.mkForce false;
  boot.kernelPackages = pkgs.linuxPackages_6_8; # Use older kernel for VirtualBox
  shanetrs.hardware = {
    enable = true;
    graphics = "virtualbox";
  };
  # user.home.packages = with pkgs; [ local.nix-software-center gtk3 ];
}
