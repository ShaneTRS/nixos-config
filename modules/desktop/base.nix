{
  config,
  fn,
  lib,
  machine,
  pkgs,
  ...
}: let
  inherit (builtins) attrNames concatStringsSep length;
  inherit (fn) configs transformAttrs;
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
      default = {extraPackages = with pkgs; [xfce4-panel-profiles];};
      win95 = {extraPackages = with pkgs; [palemoon-bin];} // default;
    };
    wm = {
      default = {};
      niri = {};
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
        default = length cfg.keymap.keymap + length cfg.keymap.modmap != 0;
      };
      devices = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      defaultMode = mkOption {
        type = types.str;
        default = "default";
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
      transforms = mkOption {
        type = types.listOf types.anything;
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
      services.udev.packages = [pkgs.brightnessctl];
      xdg.portal.enable = mkIf (length config.xdg.portal.extraPortals != 0) true;
      user = {
        home.packages = cfg.extraPackages;
        xdg.portal.enable = mkIf (length config.user.xdg.portal.extraPortals != 0) true;
      };
      users.groups = {
        video.members = [machine.user];
        input.members = [machine.user];
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
      users.groups.uinput.members = [machine.user];
      user.systemd.user.services = {
        xremap = let
          yaml =
            removeAttrs
            (cfg.keymap
              // {
                virtual_modifiers = cfg.keymap.virtualModifiers;
                default_mode = cfg.keymap.defaultMode;
              })
            ["defaultMode" "devices" "enable" "transforms" "virtualModifiers"];
          transformedYaml = transformAttrs cfg.keymap.transforms yaml;
          deviceString = concatStringsSep " " (map (x: "--device " + x) cfg.keymap.devices);
        in {
          Unit.Description = "Key remapper for X11 and Wayland";
          Service.ExecStart = "${getExe pkgs.xremap} --mouse ${deviceString} ${fn.toYAML transformedYaml}";
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
        home.sessionVariables.QT_QPA_PLATFORM = "wayland";
        xdg.configFile."XCompose" = let
          attempt = configs ".XCompose";
        in
          mkIf (attempt != null) {
            text =
              builtins.readFile "${pkgs.libx11}/share/X11/locale/en_US.UTF-8/Compose"
              + builtins.readFile attempt;
          };
      };
    })
  ]);
}
