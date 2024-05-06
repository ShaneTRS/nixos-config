{ config, lib, pkgs, machine, ... }:
let
  cfg = config.shanetrs.hardware;
  inherit (lib) mkEnableOption mkIf mkMerge mkOption types;
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
      type = types.enum [ "redist" "all" null ];
      default = null;
    };
    graphics = mkOption {
      type = types.enum [ "intel" "nvidia" "virtualbox" null ];
      default = null;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.drivers.g710.enable {
      environment.etc."sidewinderd.conf".text = ''
        user = "${cfg.drivers.g710.user}";
        capture_delays = ${if cfg.drivers.g710.captureDelays then "true" else "false"};
        pid-file = "${cfg.drivers.g710.pidFile}";
        encrypted_workdir = ${if cfg.drivers.g710.encryptedWorkDir then "true" else "false"};
        ${if cfg.drivers.g710.workDir != null then ''workdir = "${cfg.drivers.g710.workDir}";'' else ""}
      '';
      systemd.services.sidewinderd = {
        script = "${pkgs.local.sidewinderd}/bin/sidewinderd";
        wantedBy = [ "multi-user.target" ];
      };
    })

    (mkIf cfg.drivers.artist12.enable {
      environment.systemPackages = with pkgs; [ libsForQt5.xp-pen-deco-01-v2-driver ];
    })

    (mkIf (cfg.firmware != null) {
      hardware = {
        enableRedistributableFirmware = mkIf (cfg.firmware == "redist") true;
        enableAllFirmware = mkIf (cfg.firmware == "all") true;
      };
    })

    (mkIf (cfg.graphics == "nvidia") {
      services.xserver.videoDrivers = [ "nvidia" ];
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
