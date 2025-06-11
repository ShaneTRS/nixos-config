# Persephone
{...}: {
  boot = {
    kernelModules = ["kvm-amd"];
    # blacklistedKernelModules = [ "amdgpu" ];
    # kernelParams = ["i915.force_probe=!56a0" "xe.force_probe=56a0"];
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
  user.xdg.configFile.
    "wireplumber/wireplumber.conf.d/doqaus-priority.conf".text = builtins.toJSON {
    "monitor.alsa.rules" = [
      {
        matches = [{"node.name" = "bluez_output.F4_4E_FC_DA_61_E5.1";}];
        actions.update-props = {"priority.session" = 1100;};
      }
    ];
  };
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 49152;
    }
  ];
}
