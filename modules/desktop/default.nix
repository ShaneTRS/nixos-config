{
  config,
  lib,
  machine,
  pkgs,
  ...
}: let
  inherit (builtins) attrNames concatStringsSep length replaceStrings;
  inherit (lib) getExe mkDefault mkEnableOption mkIf mkMerge mkOption types;
  inherit (lib.tundra) getConfig toYAML transformAttrs;

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
    audio = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      autoSwitchOrder = mkOption {
        type = types.attrsOf types.int;
        default = {};
      };
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
      default = with pkgs; (this.extraPackages or []) ++ [shanetrs.xdg-open];
      example = with pkgs; [flite];
    };
  };

  nixos = mkIf cfg.enable (mkMerge [
    {
      hardware.bluetooth.enable = true;
      security.rtkit.enable = true; # Interactive privilege escalation
      services.udev.packages = [pkgs.brightnessctl];
      xdg.portal.enable = mkIf (length config.xdg.portal.extraPortals != 0) true;
      users.groups = {
        video.members = [machine.user];
        input.members = [machine.user];
      };
    }

    (mkIf cfg.audio.enable {
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
        wireplumber = mkIf (cfg.audio.autoSwitchOrder != {}) {
          extraConfig."51-shanetrs-always-switch" = {
            "wireplumber.components" = [
              {
                name = "shanetrs-always-switch.lua";
                type = "script/lua";
                provides = "shanetrs.always-switch";
              }
            ];
            "wireplumber.profiles" = {
              main = {"shanetrs.always-switch" = "required";};
            };
          };
          extraScripts = {
            "shanetrs-always-switch.lua" = ''
              set_default = function(name)
                if not metadata or not name then return end
                metadata:set(0, 'default.configured.audio.sink', 'Spa:String:JSON', '{ "name": "' .. name .. '" }')
                last = name
                Log.info("default sink set to " .. name)
              end
              set_fallback = function(name)
                fallback = name
                Log.info("fallback sink set to " .. (name or "nil"))
              end
              refresh_metadata = function()
                local this = om:lookup { Constraint { 'metadata.name', 'equals', 'default' } }
                if not this then return end
                metadata = this
                default = metadata:find(0, 'default.configured.audio.sink')
              end
              order = {
                ${concatStringsSep ",\n  " ((map (x: "['${replaceStrings ["*"] [""] x}'] = ${toString cfg.audio.autoSwitchOrder.${x}}")) (attrNames cfg.audio.autoSwitchOrder))}
              }
              om = ObjectManager {
                Interest { type = 'metadata', Constraint { 'metadata.name', 'equals', 'default' } },
                ${concatStringsSep ",\n  " ((map (x: "Interest { type = 'node', Constraint { 'node.name', 'matches', '${x}' } }")) (attrNames cfg.audio.autoSwitchOrder))}
              }
              om:connect('object-added', function (om, node)
                local name = node.properties['node.name']
                if not name then return end
                refresh_metadata()
                local node_order = 0; local default_order = nil
                for k, v in pairs(order) do
                  if string.find(name, k, 1, true) then node_order = v end
                  if default and string.find(default, k, 1, true) then default_order = v end
                end
                if default_order and node_order > default_order then
                  set_fallback(name)
                  return
                end
                set_fallback(default)
                set_default(name)
              end)
              om:connect('object-removed', function (om, node)
                local name = node.properties['node.name']
                if not name then return end
                refresh_metadata()
                if default and string.find(default, name, 1, true) and name == last then
                  set_default(fallback)
                end
              end)
              om:activate()
            '';
          };
        };
      };
    })

    (mkIf cfg.keymap.enable {
      hardware.uinput.enable = true;
      users.groups.uinput.members = [machine.user];
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
    })
  ]);

  home = mkIf cfg.enable (mkMerge [
    {
      home.packages = cfg.extraPackages;
      xdg.portal.enable = mkIf (length config.xdg.portal.extraPortals != 0) true;
    }

    (mkIf cfg.keymap.enable {
      systemd.user.services = {
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
          Service.ExecStart = "${getExe pkgs.xremap} --mouse ${deviceString} ${toYAML transformedYaml}";
          Install.WantedBy = ["graphical-session.target"];
        };
      };
    })

    # Or Plasma, because SDDM requires the X Server
    (mkIf (cfg.type == "x11" || cfg.session == "plasma") {
      home.sessionVariables = {
        XCOMPOSEFILE = "${config.xdg.configHome}/XCompose";
        XCOMPOSECACHE = "${config.xdg.cacheHome}/XCompose";
      };
      xdg.configFile."XCompose" = let
        attempt = getConfig ".XCompose";
      in
        mkIf (attempt != null) {source = attempt;};
    })

    (mkIf (cfg.type == "wayland") {
      home.sessionVariables.QT_QPA_PLATFORM = "wayland";
      xdg.configFile."XCompose" = let
        attempt = getConfig ".XCompose";
      in
        mkIf (attempt != null) {
          text = ''
            include "${pkgs.libx11}/share/X11/locale/en_US.UTF-8/Compose"
            include "${attempt}"
          '';
        };
    })
  ]);
}
