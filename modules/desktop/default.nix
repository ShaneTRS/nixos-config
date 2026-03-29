{
  config,
  lib,
  machine,
  pkgs,
  ...
}: let
  inherit (builtins) length;
  inherit (lib) mkDefault mkEnableOption mkIf mkMerge mkOption types;
  inherit (lib.tundra) getConfig;
  cfg = config.shanetrs.desktop;
in {
  options.shanetrs.desktop = {
    enable = mkEnableOption "Desktop environment and display manager configuration";
    type = mkOption {
      type = types.enum ["x11" "wayland"];
      default = "x11";
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [shanetrs.uri-open];
      example = with pkgs; [flite];
    };
  };

  nixos = mkIf cfg.enable (mkMerge [
    {
      hardware.bluetooth.enable = true;
      security.rtkit.enable = true; # Interactive privilege escalation
      services = {
        displayManager.autoLogin = {
          enable = mkDefault true;
          user = machine.user;
        };
        udev.packages = [pkgs.brightnessctl];
      };
      xdg.portal.enable = mkIf (length config.xdg.portal.extraPortals != 0) true;
      users.groups = {
        video.members = [machine.user];
        input.members = [machine.user];
      };
    }

    (mkIf (cfg.type == "x11") {
      services.xserver = {
        enable = true;
        xkb.options = "compose:menu";
      };
    })
  ]);

  home = mkIf cfg.enable (mkMerge [
    {
      home.packages = cfg.extraPackages;
      xdg.portal.enable = mkIf (length config.xdg.portal.extraPortals != 0) true;
      home.sessionVariables = {
        XCOMPOSEFILE = "${config.xdg.configHome}/XCompose";
        XCOMPOSECACHE = "${config.xdg.cacheHome}/XCompose";
      };
      xdg.configFile."XCompose" = let
        attempt = getConfig ".XCompose";
      in
        mkIf (attempt != null) {
          text = ''
            include "${pkgs.libx11}/share/X11/locale/en_US.UTF-8/Compose"
            include "${attempt}"
          '';
        };
    }

    (mkIf (cfg.type == "wayland") {
      home.sessionVariables.QT_QPA_PLATFORM = "wayland";
    })
  ]);
}
