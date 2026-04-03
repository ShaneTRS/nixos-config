{
  config,
  lib,
  ...
}: let
  inherit (builtins) attrNames concatStringsSep replaceStrings;
  inherit (lib) mkIf mkOption types;
  pcfg = config.shanetrs.desktop;
  cfg = pcfg.audio;
in {
  options.shanetrs.desktop.audio = {
    enable = mkOption {
      type = types.bool;
      default = pcfg.enable;
    };
    autoSwitchOrder = mkOption {
      type = types.attrsOf types.int;
      default = {};
    };
  };

  config = mkIf cfg.enable {
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber = mkIf (cfg.autoSwitchOrder != {}) {
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
              ${concatStringsSep ",\n  " ((map (x: "['${replaceStrings ["*"] [""] x}'] = ${toString cfg.autoSwitchOrder.${x}}")) (attrNames cfg.autoSwitchOrder))}
            }
            om = ObjectManager {
              Interest { type = 'metadata', Constraint { 'metadata.name', 'equals', 'default' } },
              ${concatStringsSep ",\n  " ((map (x: "Interest { type = 'node', Constraint { 'node.name', 'matches', '${x}' } }")) (attrNames cfg.autoSwitchOrder))}
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
  };
}
