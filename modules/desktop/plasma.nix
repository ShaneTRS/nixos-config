{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOptionDefault;
  cfg = config.shanetrs.desktop;
in {
  config = mkIf (cfg.enable && cfg.session == "plasma") {
    shanetrs.browser = {
      firefox = {
        extensions = mkOptionDefault ["plasma-browser-integration@kde.org:plasma-integration/latest"];
        _.nativeMessagingHosts = mkOptionDefault [pkgs.kdePackages.plasma-browser-integration];
      };
      chromium.extensions = mkOptionDefault ["cimiefiiaegbelhefglklhhakcgmhkai"]; # Plasma Integration
    };
  };

  nixos = mkIf (cfg.enable && cfg.session == "plasma") {
    # Maybe try to use plasma-manager for some settings
    programs = {
      kdeconnect.enable = true; # opens firewall
      partition-manager.enable = true; # polkit and dbus
    };
    services = {
      displayManager = {
        sddm = {
          enable = true;
          wayland.enable = mkIf (cfg.type == "wayland") true;
        };
        defaultSession =
          if cfg.type == "x11"
          then "plasmax11"
          else "plasma";
      };
      desktopManager.plasma6.enable = true;
    };
  };

  home = mkIf (cfg.enable && cfg.session == "plasma") {
    services.kdeconnect = {
      enable = true;
      indicator = true;
    };
  };
}
