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
    initrd.availableKernelModules = ["xhci_pci" "usb_storage" "rtsx_pci_sdmmc"];
    kernelModules = ["kvm-amd"];
    extraModprobeConfig = "options rtw89_pci disable_aspm_l1=1 disable_aspm_l1ss=1";
  };
  programs.xppen.enable = true;
  shanetrs.hardware = {
    iio-sensors = {
      enable = true;
      accel.enable = "vertical";
    };
  };
  hardware = {
    cpu.amd.updateMicrocode = true;
    sensor.iio.enable = true;
  };
  services.xserver.wacom.enable = true;
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
