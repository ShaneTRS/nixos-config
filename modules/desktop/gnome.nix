{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;

  pcfg = config.shanetrs.desktop;
  cfg = pcfg.gnome;
  enabled = pcfg.enable && cfg.enable;
in {
  options.shanetrs.desktop.gnome = {
    enable = mkEnableOption "GNOME and GDM configuration";
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
    };
  };

  nixos = mkIf enabled {
    environment.gnome.excludePackages = with pkgs; [
      gnome-contacts
      gnome-logs
      gnome-music
      gnome-tour
      yelp
    ];
    services.xserver = {
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
    };
    # Workaround for a bug
    systemd.services = {
      "getty@tty1".enable = false;
      "autovt@tty1".enable = false;
    };
  };

  home = mkIf enabled {
    home.packages = cfg.extraPackages;
    dconf = {
      enable = true;
      settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
    };
  };
}
