# Persephone
{
  pkgs,
  lib,
  ...
}: {
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
  user.systemd.user.services = {
    bluetooth-switch = {
      Unit = {
        After = "pipewire.service";
        Description = "Switch to specified device automatically on connection";
      };
      Service = {
        Environment = ["DEVICE=bluez_output.F4:4E:FC:DA:61:E5"];
        ExecStart = let
          inherit (pkgs) writeShellApplication;
          inherit (lib) getExe;
        in "${getExe (writeShellApplication {
          name = "bluetooth-switch.service";
          runtimeInputs = with pkgs; [pipewire wireplumber];
          text = ''
            set +o errexit
            while true; do
            	SINK="$(pw-cli ls "$DEVICE" | awk -F'[ ,]+' 'NR==1 {print $2; exit}')"
            	if [ -n "$SINK" ]; then
             		wpctl set-default "$SINK"
               	until [ -z "$(pw-cli ls "$DEVICE")" ]; do
                	sleep 10
                done
              fi
             	sleep 1
            done
          '';
        })}";
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 49152;
    }
  ];
}
