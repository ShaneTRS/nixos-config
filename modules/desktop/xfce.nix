{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkMerge mkOption types;
  inherit (pkgs.shanetrs) s_chicago95;
  pcfg = config.shanetrs.desktop;
  cfg = pcfg.xfce;
  opt = options.shanetrs.desktop.xfce;
  enabled = pcfg.enable && cfg.enable;
in {
  options.shanetrs.desktop.xfce = {
    enable = mkEnableOption "Window manager and display manager configuration";
    presets = {
      win95.enable = mkEnableOption "Win95 theme and configuration";
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
    };
  };

  config = mkIf enabled (mkMerge [
    {
      xdg.portal.extraPortals = with pkgs; [xdg-desktop-portal-gtk];
      services = {
        displayManager.defaultSession = "xfce";
        xserver.desktopManager.xfce.enable = true;
      };
      shanetrs.desktop.xfce.extraPackages = opt.extraPackages.default;
      tundra.packages = cfg.extraPackages;
    }
    (mkIf cfg.presets.win95.enable {
      shanetrs.desktop.xfce.extraPackages = with pkgs; [s_chicago95 xfce4-xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin];
      fonts = {
        packages = [s_chicago95];
        fontconfig.allowBitmaps = true;
      };

      tundra = {
        home = {
          ".gtkrc-2.0".source = "${s_chicago95}/import/.gtkrc-2.0";
          ".moonchild productions" = {
            type = "recursive";
            source = "${s_chicago95}/import/.moonchild productions/";
          };
          ".xinitrc".text = ''
            pw-play "${s_chicago95}/share/sounds/Chicago95/startup.ogg" & true
          '';
        };
        xdg.config = {
          "gtk-3.0" = {
            type = "recursive";
            source = "${s_chicago95}/import/gtk-3.0/";
          };
          "xfce4" = {
            type = "recursive";
            source = "${s_chicago95}/import/xfce4/";
          };
        };
      };
      systemd.user.services.chicago95 = {
        script = "${s_chicago95}/import/install.sh";
        wantedBy = ["default.target"];
      };
    })
  ]);
}
