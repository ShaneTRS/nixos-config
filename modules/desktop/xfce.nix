{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkMerge mkOption types;
  chicago95 = pkgs.shanetrs.chicago95;

  pcfg = config.shanetrs.desktop;
  cfg = pcfg.xfce;
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

  nixos = mkIf enabled (mkMerge [
    {
      xdg.portal.extraPortals = with pkgs; [xdg-desktop-portal-gtk];
      services = {
        displayManager.defaultSession = "xfce";
        xserver.desktopManager.xfce.enable = true;
      };
    }
    (mkIf cfg.presets.win95.enable {
      fonts = {
        packages = [chicago95];
        fontconfig.allowBitmaps = true;
      };
      environment.systemPackages = with pkgs.xfce; [xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin];
    })
  ]);

  home = mkIf enabled (mkMerge [
    (mkIf cfg.presets.win95.enable {
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
