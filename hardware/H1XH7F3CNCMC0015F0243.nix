# Inspiron 3501
{pkgs, ...}: {
  boot.loader = {
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
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/ROOT";
      fsType = "ext4";
      neededForBoot = true;
    };
    "/boot/efi" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
      neededForBoot = true;
    };
  };
  hardware.cpu.intel.updateMicrocode = true;
  nix.settings = {
    substituters = ["http://shanetrs.remote.host:5698"];
    trusted-public-keys = ["shanetrs.remote.host:p4NJFHHtAvg/kfGELDDee1zOFETgGHLBqrT8HiiBnjQ="];
  };
  shanetrs = {
    desktop.keymap.keymap = let
      backlight = pkgs.lib.getExe (pkgs.writeShellScriptBin "backlight-8b501" ''
        export DISPLAY=:0
        mkdir -p /tmp/backlight
        processes=(`pgrep backlight-8b501`)

        max=`cat /sys/class/backlight/intel_backlight/max_brightness`
        bl_set() {
          val=$1
          echo $val
          [[ $val -gt $max ]] && val=$max
          [[ $val -lt 1 ]] && val=1
          echo "$val" > /tmp/backlight/actual_brightness
          dbus-send --session --type=method_call --dest=org.kde.Solid.PowerManagement \
            "/org/kde/Solid/PowerManagement/Actions/BrightnessControl" org.kde.Solid.PowerManagement.Actions.BrightnessControl.setBrightness int32:$val &
          true
        }
        bl_set_perc () { bl_set $((max * $1 / 100)); }
        bl_step () { bl_set $(( `cat /tmp/backlight/actual_brightness || cat /sys/class/backlight/intel_backlight/actual_brightness` + $1)); }
        bl_step_perc () { bl_step $((max * $1 / 100)); }

        [[ "$2" ]] || exit
        val=''${val:-$(( $2*''${#processes[@]} ))}
        eval "bl_$1 $val"
        sleep 0.2
      '');
    in [
      {
        "name" = "H1XH7F3CNCMC0015F0243";
        "remap" = {
          "pageup" = "home";
          "pagedown" = "end";
          "home" = "pageup";
          "end" = "pagedown";
          "alt-f6" = {launch = [backlight "step_perc" "-1"];};
          "alt-f7" = {launch = [backlight "step_perc" "1"];};
        };
      }
    ];
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
      ports = ["1-6"];
    };
  };
  # services.fprintd = {
  #   enable = true;
  #   tod = {
  #     enable = true;
  #     driver = pkgs.libfprint-2-tod1-goodix;
  #   };
  # };
}
