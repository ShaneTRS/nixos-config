# HP EliteBook 840 G1 (A3009CD10002)
{ pkgs, ... }: {
  boot = {
    kernelPackages = pkgs.linuxPackages_5_15;
    kernelParams = [ "intel_iommu=off" "acpi_backlight=native" "acpi_sleep=nonvs" ];
    loader.grub = {
      enable = true;
      device = "/dev/sda";
      # useOSProber = true;
      extraEntries = ''
        menuentry 'Windows 10 (on /dev/sda1)' --class windows --class os $menuentry_id_option 'osprober-chain-DA1AD5FE1AD5D799' {
          insmod part_msdos
          insmod ntfs
          set root='hd0,msdos1'
          if [ x$feature_platform_search_hint = xy ]; then
            search --no-floppy --fs-uuid --set=root --hint-bios=hd0,msdos1 --hint-efi=hd0,msdos1 --hint-baremetal=ahci0,msdos1  DA1AD5FE1AD5D799
          else
            search --no-floppy --fs-uuid --set=root DA1AD5FE1AD5D799
          fi
          parttool ''${root} hidden-
          drivemap -s (hd0) ''${root}
          chainloader +1
        }
        menuentry 'Arch Linux (on /dev/sda3)' --class arch --class gnu-linux --class gnu --class os $menuentry_id_option 'osprober-gnulinux-simple-f6bc0a26-1e47-4a66-8f3d-9ab04f5f190d' {
          insmod part_msdos
          insmod ext2
          set root='hd0,msdos3'
          if [ x$feature_platform_search_hint = xy ]; then
            search --no-floppy --fs-uuid --set=root --hint-bios=hd0,msdos3 --hint-efi=hd0,msdos3 --hint-baremetal=ahci0,msdos3  f6bc0a26-1e47-4a66-8f3d-9ab04f5f190d
          else
            search --no-floppy --fs-uuid --set=root f6bc0a26-1e47-4a66-8f3d-9ab04f5f190d
          fi
          linux /boot/vmlinuz-linux root=UUID=f6bc0a26-1e47-4a66-8f3d-9ab04f5f190d rw loglevel=3 acpi_backlight=native acpi_sleep=nonvs
          initrd /boot/initramfs-linux.img
        }
      '';
    };
  };
  fileSystems."/" = {
    device = "/dev/disk/by-label/Nix";
    fsType = "btrfs";
    options = [ "compress-force=zstd:6" ];
    neededForBoot = true;
  };
  hardware.cpu.intel.updateMicrocode = true;
  nix = {
    settings.max-jobs = 1;
    distributedBuilds = true;
    buildMachines = [{
      hostName = "192.168.1.11?ssh-key=/root/.ssh/shane_ed25519";
      sshUser = "shane";
      systems = [ "x86_64-linux" ];
      supportedFeatures = [ "benchmark" "big-parallel" "kvm" ];
      maxJobs = 6;
      speedFactor = 5;
    }];
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
      ports = [ "2-2" "2-4" "1-2" "1-4" ];
    };
  };
  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 8192;
  }];
}
