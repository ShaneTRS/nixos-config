# HP t530 Thin Client
{...}: {
  boot = {
    kernelModules = ["kvm-amd"];
    kernelParams = ["radeon.si_support=0" "amdgpu.si_support=1" "radeon.cik_support=0" "amdgpu.cik_support=1"];
    loader.grub = {
      enable = true;
      device = "/dev/sda";
    };
  };
  fileSystems."/" = {
    device = "/dev/disk/by-label/Nix";
    fsType = "ext4";
    neededForBoot = true;
  };
  hardware = {
    cpu.amd.updateMicrocode = true;
  };
  nix.settings = {
    substituters = ["http://shanetrs.remote.host:5698"];
    trusted-public-keys = ["shanetrs.remote.host:p4NJFHHtAvg/kfGELDDee1zOFETgGHLBqrT8HiiBnjQ="];
  };
  shanetrs = {
    hardware = {
      enable = true;
      drivers.g710 = {
        enable = true;
        captureDelays = false;
      };
      firmware = "redist";
    };
    remote = {
      addresses.client = "192.168.1.13";
      usb = {
        devices = "/sys/bus/pci/devices/0000:00:12.0/usb";
        ports = ["1-1.1" "1-1.2"];
      };
    };
  };
}
