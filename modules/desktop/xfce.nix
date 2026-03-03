{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  chicago95 = pkgs.shanetrs.chicago95;

  cfg = config.shanetrs.desktop;
in {
  nixos = mkIf cfg.enable (mkMerge [
    (mkIf (cfg.session == "xfce") {
      xdg.portal.extraPortals = with pkgs; [xdg-desktop-portal-gtk];
      services = {
        displayManager.defaultSession = "xfce";
        xserver.desktopManager.xfce.enable = true;
      };
    })

    (mkIf (cfg.session == "xfce" && cfg.preset == "win95") {
      fonts = {
        packages = [chicago95];
        fontconfig.allowBitmaps = true;
      };
      environment.systemPackages = with pkgs.xfce; [xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin];
    })
  ]);

  home = mkIf cfg.enable (mkMerge [
    (mkIf (cfg.session == "xfce" && cfg.preset == "win95") {
      xdg.configFile = {
        "gtk-3.0" = {
          recursive = true;
          source = "${chicago95}/import/gtk-3.0/";
        };
        "xfce4" = {
          recursive = true;
          source = "${chicago95}/import/xfce4/";
        };
      };
      home = {
        file = {
          ".gtkrc-2.0".source = "${chicago95}/import/.gtkrc-2.0";
          ".moonchild productions" = {
            recursive = true;
            source = "${chicago95}/import/.moonchild productions/";
          };
        };
        packages = [chicago95];
      };
      systemd.user.services.chicago95 = {
        Unit.Description = "Chicago95 installer";
        Service.ExecStart = "${chicago95}/import/install.sh";
        Install.WantedBy = ["default.target"];
      };
      xsession = {
        enable = true;
        profileExtra = ''
          pw-play "${chicago95}/share/sounds/Chicago95/startup.ogg" & true
        '';
      };
    })
  ]);
}
