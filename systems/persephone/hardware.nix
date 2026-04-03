# Persephone
{config, ...}: {
  shanetrs = {
    hardware = {
      enable = true;
      drivers.g710 = {
        enable = true;
        captureDelays = false;
      };
      gpu = "intel";
    };
    desktop.audio.autoSwitchOrder = {
      "bluez_output_internal.*" = 1;
      "alsa_output.pci-0000_04_00.0.hdmi*" = 2;
    };
  };

  boot = {
    kernelModules = ["kvm-amd"];
    # blacklistedKernelModules = [ "amdgpu" ];
    kernelParams = ["i915.force_probe=!56a0" "xe.force_probe=56a0"];
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
  systemd.services.podman-autostart.after = ["run-media-${config.tundra.user}-Felix\\x2dPP.mount"];
  hardware.cpu.amd.updateMicrocode = true;

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 49152;
    }
  ];
}
