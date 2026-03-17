{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) attrNames listToAttrs toJSON;
  inherit (lib) mkEnableOption mkIf mkOption mkPackageOption types;
  inherit (lib.tundra) configs;
  cfg = config.shanetrs.programs.easyeffects;
in {
  options.shanetrs.programs.easyeffects = {
    enable = mkEnableOption "EasyEffects configuration and installation";
    package = mkPackageOption pkgs "easyeffects" {};
    extraPresets = mkOption {
      type = types.attrs;
      default = {};
    };
  };

  nixos = mkIf cfg.enable {
    programs.dconf.enable = true; # settings daemon
  };

  home = mkIf cfg.enable {
    home.packages = [cfg.package];
    xdg.configFile = let
      attempt = configs "easyeffects";
    in
      {
        "easyeffects" = mkIf (attempt != null) {
          recursive = true;
          source = attempt;
        };
      }
      // listToAttrs (map (k: {
          name = "easyeffects/output/${k}.json";
          value = {text = toJSON cfg.extraPresets.${k};};
        })
        (attrNames cfg.extraPresets));
  };
}
