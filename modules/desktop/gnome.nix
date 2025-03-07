{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  cfg = config.shanetrs.desktop;
in {
  config = mkIf cfg.enable (mkMerge [
    (mkIf (cfg.session == "gnome") {
      environment.gnome.excludePackages = with pkgs; [
        gnome-contacts
        gnome-logs
        gnome-music
        gnome-tour
        yelp
      ];
      user = {
        dconf = {
          enable = true;
          settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
        };
      };
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

    (mkIf (cfg.session == "gnome" && cfg.preset == "pop") {
      user = {
        dconf.settings = {"org/gnome/shell".enabled-extensions = ["pop-shell@system76.com"];};
        home.packages = with pkgs; [gnomeExtensions.pop-shell];
      };
    })
  ]);
}
