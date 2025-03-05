# HP EliteBook 840 G1 (A3009CD10002)
{pkgs, ...}: {
  boot = {
    kernelPackages = pkgs.linuxPackages_5_15;
    kernelParams = ["intel_iommu=off" "acpi_backlight=native" "acpi_sleep=nonvs"];
    loader.grub = {
      enable = true;
      device = "/dev/sda";
      # useOSProber = true;
      extraEntries = ''
        menuentry 'Windows 10' --class windows --class os $menuentry_id_option 'osprober-chain-Windows' {
          insmod part_msdos
          insmod ntfs
          search --no-floppy --label "System Reserved" --set=root
          parttool ''${root} hidden-
          drivemap -s (hd0) ''${root}
          chainloader +1
        }
        menuentry 'Arch Linux' --class arch --class gnu-linux --class gnu --class os $menuentry_id_option 'osprober-gnulinux-simple-f6bc0a26-1e47-4a66-8f3d-9ab04f5f190d' {
          insmod part_msdos
          insmod ext2
          search --no-floppy --label Arch --set=root
          linux /boot/vmlinuz-linux root=LABEL=Arch rw loglevel=3 intel_iommu=off acpi_backlight=native acpi_sleep=nonvs
          initrd /boot/initramfs-linux.img
        }
      '';
    };
  };
  fileSystems."/" = {
    device = "/dev/disk/by-label/Nix";
    fsType = "btrfs";
    options = ["compress-force=zstd:6"];
    neededForBoot = true;
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
      ports = ["2-7"];
    };
  };
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8192;
    }
  ];
}
