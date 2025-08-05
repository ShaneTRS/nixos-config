{
  config,
  fn,
  lib,
  machine,
  pkgs,
  ...
}: let
  inherit (builtins) attrNames length;
  inherit (fn) configs;
  inherit (lib) getExe mkDefault mkEnableOption mkIf mkMerge mkOption types;

  sessions = {
    plasma = {
      default = {
        extraPackages = with pkgs.kdePackages; [
          ark
          filelight
          kate
          kfind
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
    keymap = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      keymap = mkOption {
        type = types.listOf types.attrs;
        default = [];
      };
      modmap = mkOption {
        type = types.listOf types.attrs;
        default = [];
      };
      virtualModifiers = mkOption {
        type = types.listOf types.str;
        default = [];
      };
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
      xdg.portal.enable = mkIf (length config.xdg.portal.extraPortals != 0) true;
      user = {
        home.packages = cfg.extraPackages;
        xdg.portal.enable = mkIf (length config.user.xdg.portal.extraPortals != 0) true;
      };
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

    (mkIf cfg.keymap.enable {
      hardware.uinput.enable = true;
      users.users.${machine.user}.extraGroups = ["input" "uinput"];
      user.systemd.user.services = {
        xremap = let
          yaml =
            builtins.removeAttrs
            (cfg.keymap // {virtual_modifiers = cfg.keymap.virtualModifiers;})
            ["enable" "virtualModifiers"];
        in {
          Unit.Description = "Key remapper for X11 and Wayland";
          Service.ExecStart = "${getExe pkgs.shanetrs.xremap} ${fn.toYAML {inherit pkgs;} yaml}";
          Install.WantedBy = ["graphical-session.target"];
        };
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

    (mkIf (cfg.type == "wayland") {
      user = {
        xdg.configFile."XCompose" = let
          attempt = configs ".XCompose";
        in
          mkIf (attempt != null) {
            text =
              builtins.readFile "${pkgs.xorg.libX11}/share/X11/locale/en_US.UTF-8/Compose"
              + builtins.readFile attempt;
          };
      };
    })
  ]);
}
