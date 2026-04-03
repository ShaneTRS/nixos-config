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
    programs.niri.enable = true;
    tundra = {
      packages = with pkgs; [
        xwayland-satellite
        adwaita-icon-theme
      ];
      environment.variables = {
        SCREENSHOT = "niri msg action screenshot";
        LAUNCHER = "${getExe pkgs.rofi} -show drun";
      };
    };
    # service.dbus.packages = with pkgs; [niri];
  };
}
