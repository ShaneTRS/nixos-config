{
  config,
  lib,
  machine,
  pkgs,
  ...
}: let
  inherit (builtins) concatStringsSep length;
  inherit (lib) getExe mkIf mkOption types;
  inherit (lib.tundra) toYAML transformAttrs;
  cfg = config.shanetrs.desktop.keymap;
in {
  options.shanetrs.desktop.keymap = {
    enable = mkOption {
      type = types.bool;
      default = length cfg.keymap + length cfg.modmap != 0;
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

  nixos = mkIf cfg.enable {
    hardware.uinput.enable = true;
    users.groups.uinput.members = [machine.user];
  };

  home = mkIf cfg.enable {
    systemd.user.services = {
      xremap = let
        yaml =
          removeAttrs
          (cfg
            // {
              virtual_modifiers = cfg.virtualModifiers;
              default_mode = cfg.defaultMode;
            })
          ["defaultMode" "devices" "enable" "transforms" "virtualModifiers"];
        transformedYaml = transformAttrs cfg.transforms yaml;
        deviceString = concatStringsSep " " (map (x: "--device " + x) cfg.devices);
      in {
        Unit.Description = "Key remapper for X11 and Wayland";
        Service.ExecStart = "${getExe pkgs.xremap} --mouse ${deviceString} ${toYAML transformedYaml}";
        Install.WantedBy = ["graphical-session.target"];
      };
    };
  };
}
