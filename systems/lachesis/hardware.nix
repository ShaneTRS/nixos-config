# Inspiron 3501
{
  machine,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getExe;
in {
  config.shanetrs = {
    desktop.keymap = {
      devices = ["keyboard" "Video"];
      keymap = [
        {
          name = machine.serial + "-ungrab";
          remap = let
            brightness = amount: direction: {
              launch = [
                (getExe (pkgs.writeShellApplication {
                  name = "brightness-8b501";
                  runtimeInputs = with pkgs; [brightnessctl procps];
                  text = ''
                    brightnessctl --class=backlight set "$(( ''${1:-1} * $(pgrep -fc "$0") ** 4))''${2:-+}"
                    sleep 1
                  '';
                }))
                amount
                direction
              ];
            };
          in {
            pageup = "home";
            pagedown = "end";
            home = "pageup";
            end = "pagedown";
            brightnessup = brightness "1" "+";
            brightnessdown = brightness "1" "-";
          };
        }
      ];
    };
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

  nixos = {
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
    # services.fprintd = {
    #   enable = true;
    #   tod = {
    #     enable = true;
    #     driver = pkgs.libfprint-2-tod1-goodix;
    #   };
    # };
  };
}
