{
  config,
  fn,
  lib,
  machine,
  pkgs,
  ...
}: let
  inherit (builtins) attrNames;
  inherit (fn) configs;
  inherit (lib) mkDefault mkEnableOption mkIf mkMerge mkOption types;

  sessions = {
    plasma = {
      default = {
        extraPackages = with pkgs.kdePackages; [
          ark
          filelight
          kate
          kfind
          pkgs.krename
          plasma-browser-integration
          sddm-kcm
        ];
      };
    };
    gnome = {
      default = {};
      pop = {extraPackages = with pkgs.gnomeExtensions; [pop-shell];};
    };
    xfce = rec {
      default = {extraPackages = with pkgs.xfce; [xfce4-panel-profiles];};
      win95 = {extraPackages = with pkgs; [palemoon-bin];} // default;
    };
  };
  this =
    if cfg.enable && cfg.session != null
    then sessions.${cfg.session}.${cfg.preset} or {}
    else {};

  cfg = config.shanetrs.desktop;
in {
  options.shanetrs.desktop = {
    enable = mkEnableOption "Desktop environment and display manager configuration";
    session = mkOption {
      type = types.nullOr (types.enum (attrNames sessions));
      default = null;
    };
    type = mkOption {
      type = types.enum ["x11" "wayland"];
      default = "x11";
    };
    preset = mkOption {
      type = types.enum (attrNames sessions.${cfg.session});
      default = "default";
    };
    audio = mkOption {
      type = types.bool;
      default = true;
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = this.extraPackages or [];
      example = with pkgs; [flite];
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      hardware.bluetooth.enable = true;
      security.rtkit.enable = true; # Interactive privilege escalation
      xdg.portal.enable = true;
      user.home.packages = cfg.extraPackages;
    }

    (mkIf cfg.audio {
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
      };
    })

    # Or Plasma, because SDDM requires the X Server
    (mkIf (cfg.type == "x11" || cfg.session == "plasma") {
      services = {
        displayManager.autoLogin = {
          enable = mkDefault true;
          user = machine.user;
        };
        xserver = {
          enable = true;
          xkb.options = "compose:menu";
        };
      };
      user = {
        home.sessionVariables = {
          XCOMPOSEFILE = "${config.user.xdg.configHome}/XCompose";
          XCOMPOSECACHE = "${config.user.xdg.cacheHome}/XCompose";
        };
        xdg.configFile."XCompose" = let
          attempt = configs ".XCompose";
        in
          mkIf (attempt != null) {source = attempt;};
      };
    })
  ]);
}
