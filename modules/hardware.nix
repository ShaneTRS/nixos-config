{
  config,
  lib,
  pkgs,
  machine,
  ...
}: let
  inherit (lib) getExe mkEnableOption mkIf mkMerge mkOption optionalString types;
  cfg = config.shanetrs.hardware;
in {
  options.shanetrs.hardware = {
    enable = mkEnableOption "Hardware driver installation and configuration";
    drivers = {
      artist12.enable = mkEnableOption "XP-Pen Artist 12 driver installation";
      g710 = {
        enable = mkEnableOption "Logitech G710 driver installation and configuration";
        user = mkOption {
          type = types.str;
          default = "${machine.user}";
        };
        captureDelays = mkOption {
          type = types.bool;
          default = true;
        };
        pidFile = mkOption {
          type = types.str;
          default = "/var/run/sidewinderd.pid";
        };
        encryptedWorkDir = mkOption {
          type = types.bool;
          default = false;
        };
        workDir = mkOption {
          type = types.nullOr types.str;
          default = null; # "/home/${machine.user}/.local/share/sidewinderd"
        };
      };
    };
    firmware = mkOption {
      type = types.enum ["redist" "all" null];
      default = null;
    };
    graphics = mkOption {
      type = types.enum ["intel" "nvidia" "virtualbox" null];
      default = null;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.drivers.g710.enable {
      environment.etc."sidewinderd.conf".text = with cfg.drivers.g710; ''
        user = "${user}";
        capture_delays = ${
          if captureDelays
          then "true"
          else "false"
        };
        pid-file = "${pidFile}";
        encrypted_workdir = ${
          if encryptedWorkDir
          then "true"
          else "false"
        };
        ${optionalString (workDir != null) ''workdir = "${workDir}";''}
      '';
      systemd.services.sidewinderd = {
        script = "${getExe pkgs.shanetrs.sidewinderd}";
        wantedBy = ["multi-user.target"];
      };
    })

    (mkIf cfg.drivers.artist12.enable {
      environment.systemPackages = with pkgs; [libsForQt5.xp-pen-deco-01-v2-driver];
    })

    (mkIf (cfg.firmware != null) {
      hardware = {
        enableRedistributableFirmware = mkIf (cfg.firmware == "redist") true;
        enableAllFirmware = mkIf (cfg.firmware == "all") true;
      };
    })

    (mkIf (cfg.graphics == "nvidia") {
      services.xserver.videoDrivers = ["nvidia"];
      virtualisation.podman.enableNvidia = true;
      hardware.nvidia = {
        modesetting.enable = true;
        powerManagement = {
          enable = false;
          finegrained = false;
        };
        open = false;
        # nvidiaSettings = false;
        package = config.boot.kernelPackages.nvidiaPackages.beta;
      };
    })

    (mkIf (cfg.graphics == "virtualbox") {virtualisation.virtualbox.guest.enable = true;})

    (mkIf (cfg.graphics == "intel") {
      environment.sessionVariables = {
        LIBVA_DRIVERS_PATH = "/run/opengl-driver/lib/dri";
        LIBVA_DRIVER_NAME = "iHD";
      };
      hardware.graphics.extraPackages = with pkgs; [
        intel-media-driver
        intel-compute-runtime
        vpl-gpu-rt
      ];
    })
  ]);
}
