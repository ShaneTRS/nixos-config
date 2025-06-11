# Persephone
{...}: {
  boot = {
    kernelModules = ["kvm-amd"];
    loader = {
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
  };
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/ROOT";
      fsType = "ext4";
    };
    "/boot/efi" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
    };

    "/run/media/shane/Eden" = {
      device = "/dev/disk/by-label/Eden";
      fsType = "btrfs";
      options = ["compress-force=zstd:12,nofail"];
    };
    "/run/media/shane/Felix-PP" = {
      device = "/dev/disk/by-label/Felix++";
      fsType = "btrfs";
      options = ["compress-force=zstd:12,nofail"];
    };
  };
  hardware.cpu.amd.updateMicrocode = true;
  shanetrs = {
    hardware = {
      enable = true;
      drivers.g710 = {
        enable = true;
        captureDelays = false;
      };
      firmware = "redist";
      graphics = "intel";
    };
  };
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 49152;
    }
  ];
}
