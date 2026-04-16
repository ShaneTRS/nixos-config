{...}: {
  boot = {
    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      grub = {
        enable = true;
        efiSupport = true;
        device = "nodev";
        useOSProber = true;
      };
    };
    initrd.availableKernelModules = ["nvme" "xhci_pci" "usb_storage" "rtsx_pci_sdmmc"];
    kernelModules = ["kvm-amd"];
  };
  shanetrs.hardware.drivers.artist12.enable = true;
  hardware.cpu.amd.updateMicrocode = true;
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/ROOT";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
      options = ["fmask=0022" "dmask=0022"];
    };
  };
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 32768;
    }
  ];
  tundra.user = "mo";
}
