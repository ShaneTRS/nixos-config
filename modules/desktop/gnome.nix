{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  cfg = config.shanetrs.desktop;
in {
  nixos = mkIf cfg.enable (mkMerge [
    (mkIf (cfg.session == "gnome") {
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
    })
  ]);

  home = mkIf cfg.enable (mkMerge [
    (mkIf (cfg.session == "gnome") {
      dconf = {
        enable = true;
        settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
      };
    })

    (mkIf (cfg.session == "gnome" && cfg.preset == "pop") {
      dconf.settings = {"org/gnome/shell".enabled-extensions = ["pop-shell@system76.com"];};
      home.packages = with pkgs; [gnomeExtensions.pop-shell];
    })
  ]);
}
