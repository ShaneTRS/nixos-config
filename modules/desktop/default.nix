{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) concatStringsSep mapAttrs;
  inherit (lib) mkDefault mkEnableOption mkIf mkMerge mkOption types;
  inherit (lib.tundra) mergeFormat;
  cfg = config.shanetrs.desktop;
in {
  options.shanetrs.desktop = {
    enable = mkEnableOption "Desktop environment and display manager configuration";
    type = mkOption {
      type = types.enum ["x11" "wayland"];
      default = "x11";
    };
    mime = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      added = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = {};
      };
      default = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = {};
      };
      removed = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = {};
      };
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [shanetrs.uri-open];
      example = with pkgs; [flite];
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      hardware.bluetooth.enable = true;
      security.rtkit.enable = true; # Interactive privilege escalation
      services = {
        displayManager.autoLogin = {
          enable = mkDefault true;
          user = config.tundra.user;
        };
        udev.packages = [pkgs.brightnessctl];
      };
      xdg.portal.enable = true;
      users.groups = {
        video.members = [config.tundra.user];
        input.members = [config.tundra.user];
      };
      tundra = {
        packages = cfg.extraPackages;
        environment.variables = {
          XCOMPOSEFILE = "${pkgs.writeText "XCompose" ''
            include "${pkgs.libx11}/share/X11/locale/en_US.UTF-8/Compose"
            <Multi_key> <p> <i> : "π" U03C0
          ''}";
          XCOMPOSECACHE = "${config.tundra.paths.xdg.cache}/XCompose";
        };
        xdg.config."mimeapps.list" = mkIf cfg.mime.enable {
          type = "execute";
          source = mergeFormat.ini.mime (mapAttrs (k: mapAttrs (k: concatStringsSep ";")) {
            "Added Associations" = cfg.mime.added;
            "Default Applications" = cfg.mime.default;
            "Removed Associations" = cfg.mime.removed;
          });
        };
      };
    }

    (mkIf (cfg.type == "x11") {
      services.xserver = {
        enable = true;
        xkb.options = "compose:menu";
      };
    })

    (mkIf (cfg.type == "wayland") {
      environment.sessionVariables.QT_QPA_PLATFORM = "wayland";
    })
  ]);
}
