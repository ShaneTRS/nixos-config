{ config, lib, pkgs, ... }:
let
  cfg = config.shanetrs.hardware;
  inherit (lib) mkEnableOption mkIf mkMerge mkOption types;
in {
  options.shanetrs.hardware = {
    enable = mkEnableOption "Hardware configuration and driver installation";
    graphics = mkOption { type = types.enum [ "intel" "nvidia" "virtualbox" ]; };
    firmware = mkOption {
      type = types.nullOr (types.enum [ "redist" "all" ]);
      default = null;
    };
    # drivers = mkOption {
    #   type = types.listOf (types.enum [ "g710+" ]);
    #   default = [ ];
    # };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf (cfg.firmware != null) {
      hardware = {
        enableRedistributableFirmware = mkIf (cfg.firmware == "redist") true;
        enableAllFirmware = mkIf (cfg.firmware == "all") true;
      };
    })

    (mkIf (cfg.graphics == "nvidia") {
      services.xserver.videoDrivers = [ "nvidia" ];
      boot.kernelParams = [ "nvidia-drm.modeset=1" ];
      virtualisation.podman.enableNvidia = true;
      hardware.nvidia = {
        modesetting.enable = true;
        powerManagement = {
          enable = false;
          finegrained = false;
        };
        open = false;
        nvidiaSettings = false;
        package = config.boot.kernelPackages.nvidiaPackages.beta;
      };
    })

    (mkIf (cfg.graphics == "virtualbox") {
      virtualisation.virtualbox.guest = {
        enable = true;
        x11 = true;
      };
      user.xsession = {
        enable = true;
        # This is a workaround for a NixOS option bug, I believe
        profileExtra = ''
          VBoxClient --clipboard
          VBoxClient --draganddrop
          VBoxClient --seamless
          VBoxClient --vmsvga
        '';
      };
    })

    (mkIf (cfg.graphics == "intel") { hardware.opengl.extraPackages = with pkgs; [ intel-media-driver ]; })
  ]);
}
