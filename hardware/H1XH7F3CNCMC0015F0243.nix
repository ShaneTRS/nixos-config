# Inspiron 3501 ()
{...}: {
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot/efi";
    };
    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";
      # useOSProber = true;
    };
  };
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/ROOT";
      fsType = "ext4";
      neededForBoot = true;
    };
    "/boot/efi" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
      neededForBoot = true;
    };
  };
  hardware.cpu.intel.updateMicrocode = true;
  nix.settings = {
    substituters = ["http://shanetrs.remote.host:5698"];
    trusted-public-keys = ["shanetrs.remote.host:p4NJFHHtAvg/kfGELDDee1zOFETgGHLBqrT8HiiBnjQ="];
  };
  shanetrs = {
    hardware = {
      enable = true;
      graphics = "intel";
      drivers.g710 = {
        enable = true;
        captureDelays = false;
      };
      firmware = "redist";
    };
    remote.usb = {
      devices = "/sys/bus/pci/devices/0000:00:14.0/usb";
      ports = ["1-6"];
    };
  };
}
