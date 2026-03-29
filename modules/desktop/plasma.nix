{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption mkOptionDefault types;

  pcfg = config.shanetrs.desktop;
  cfg = pcfg.plasma;
  enabled = pcfg.enable && cfg.enable;
in {
  options.shanetrs.desktop.plasma = {
    enable = mkEnableOption "KDE Plasma and SDDM configuration";
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = with pkgs.kdePackages; [
        ark
        filelight
        kate
        kfind
        plasma-browser-integration
        sddm-kcm
      ];
    };
  };

  config = mkIf enabled {
    shanetrs.browser = {
      firefox = {
        extensions = mkOptionDefault ["plasma-browser-integration@kde.org:plasma-integration/latest"];
        _.nativeMessagingHosts = mkOptionDefault [pkgs.kdePackages.plasma-browser-integration];
      };
      chromium.extensions = mkOptionDefault ["cimiefiiaegbelhefglklhhakcgmhkai"]; # Plasma Integration
    };
  };

  nixos = mkIf enabled {
    # Maybe try to use plasma-manager for some settings
    programs = {
      kdeconnect.enable = true; # opens firewall
      partition-manager.enable = true; # polkit and dbus
    };
    services = {
      displayManager = {
        sddm = {
          enable = true;
          wayland.enable = mkIf (pcfg.type == "wayland") true;
        };
        defaultSession =
          if pcfg.type == "x11"
          then "plasmax11"
          else "plasma";
      };
      desktopManager.plasma6.enable = true;
    };
  };

  home = mkIf enabled {
    home.packages = cfg.extraPackages;
    services.kdeconnect = {
      enable = true;
      indicator = true;
    };
  };
}
