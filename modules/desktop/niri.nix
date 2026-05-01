{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) getExe mkEnableOption mkIf mkOption types;
  pcfg = config.shanetrs.desktop;
  cfg = pcfg.niri;
  opt = options.shanetrs.desktop.niri;
  enabled = pcfg.enable && cfg.enable;
in {
  options.shanetrs.desktop.niri = {
    enable = mkEnableOption "Window manager and display manager configuration";
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [
        xwayland-satellite
        adwaita-icon-theme
      ];
    };
  };

  config = mkIf enabled {
    shanetrs.desktop = {
      wm.enable = true;
      niri.extraPackages = opt.extraPackages.default;
    };
    programs.niri.enable = true;
    tundra = {
      packages = cfg.extraPackages;
      environment.variables = {
        SCREENSHOT = "niri msg action screenshot";
        LAUNCHER = "${getExe pkgs.rofi} -show drun";
      };
    };
    # service.dbus.packages = with pkgs; [niri];
  };
}
