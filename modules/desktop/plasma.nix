{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;
  pcfg = config.shanetrs.desktop;
  cfg = pcfg.plasma;
  opt = options.shanetrs.desktop.plasma;
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
    shanetrs.desktop = {
      plasma.extraPackages = opt.extraPackages.default;
      mime = {
        added = {
          "inode/directory" = ["org.kde.dolphin.desktop"];
        };
        default = {
          "application/java-archive" = ["org.kde.ark.desktop"];
          "application/vnd.debian.binary-package" = ["org.kde.ark.desktop"];
          "inode/directory" = ["org.kde.dolphin.desktop"];
        };
        removed = {
          "application/octet-stream" = ["org.kde.kdeconnect_open.desktop"];
          "x-scheme-handler/http" = ["org.kde.kdeconnect_open.desktop"];
          "x-scheme-handler/https" = ["org.kde.kdeconnect_open.desktop"];
        };
      };
    };
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
    tundra.packages = cfg.extraPackages;
  };
}
