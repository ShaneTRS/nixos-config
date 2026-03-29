{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) getExe mkEnableOption mkIf mkOption types;

  pcfg = config.shanetrs.desktop;
  cfg = pcfg.niri;
  enabled = pcfg.enable && cfg.enable;
in {
  options.shanetrs.desktop.niri = {
    enable = mkEnableOption "Window manager and display manager configuration";
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
    };
  };

  config = mkIf enabled {
    shanetrs.desktop.wm.enable = true;
  };

  nixos = mkIf enabled {
    programs.niri.enable = true;
  };

  home = mkIf enabled {
    dbus.packages = with pkgs; [niri];
    home = {
      packages = with pkgs; [
        xwayland-satellite
        adwaita-icon-theme
      ];
      sessionVariables = {
        SCREENSHOT = "niri msg action screenshot";
        LAUNCHER = "${getExe pkgs.rofi} -show drun";
      };
    };
  };
}
