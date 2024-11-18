# HP t530 Thin Client
{
  boot = {
    kernelModules = [ "kvm-amd" ];
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
  shanetrs = {
    hardware = {
      enable = true;
      drivers.g710 = {
        enable = true;
        captureDelays = false;
      };
      firmware = "redist";
    };
    remote.usb = {
      devices = "/sys/bus/pci/devices/0000:00:12.0/usb";
      ports = [ "1-1.1" "1-1.2" ];
    };
  };
  hardware.cpu.amd.updateMicrocode = true;
}
