{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;
  pcfg = config.shanetrs.desktop;
  cfg = pcfg.gnome;
  opt = options.shanetrs.desktop.gnome;
  enabled = pcfg.enable && cfg.enable;
in {
  options.shanetrs.desktop.gnome = {
    enable = mkEnableOption "GNOME and GDM configuration";
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      example = [pkgs.gnome-calculator];
    };
  };

  config = mkIf enabled {
    shanetrs.desktop.gnome.extraPackages = opt.extraPackages.default;
    environment.gnome.excludePackages = with pkgs; [
      gnome-contacts
      gnome-logs
      gnome-music
      gnome-tour
      yelp
    ];
    programs.dconf.enable = true;
    services = {
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
    };
    # Workaround for a bug
    systemd.services = {
      "getty@tty1".enable = false;
      "autovt@tty1".enable = false;
    };
    tundra.packages = cfg.extraPackages;
  };
}
