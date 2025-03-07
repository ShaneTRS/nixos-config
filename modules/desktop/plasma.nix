{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkMerge mkOptionDefault;
  cfg = config.shanetrs.desktop;
in {
  config = mkIf cfg.enable (mkMerge [
    (mkIf (cfg.session == "plasma") {
      # Maybe try to use plasma-manager for some settings
      programs = {
        kdeconnect.enable = true; # opens firewall
        partition-manager.enable = true; # polkit and dbus
      };
      shanetrs.browser = {
        firefox = {
          extensions = mkOptionDefault ["plasma-browser-integration@kde.org:plasma-integration/latest"];
          _.nativeMessagingHosts = mkOptionDefault [pkgs.kdePackages.plasma-browser-integration];
        };
        chromium.extensions = mkOptionDefault ["cimiefiiaegbelhefglklhhakcgmhkai"]; # Plasma Integration
      };
      user.services.kdeconnect = {
        enable = true;
        indicator = true;
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
    })
  ]);
}
