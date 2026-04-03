{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) attrNames listToAttrs toJSON;
  inherit (lib) mkEnableOption mkIf mkOption mkPackageOption types;
  inherit (lib.tundra) getConfig;
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

  config = mkIf cfg.enable {
    programs.dconf.enable = true; # settings daemon
    tundra.packages = [cfg.package];
    tundra.xdg.config = let
      attempt = getConfig "easyeffects";
    in
      {
        "easyeffects" = mkIf (attempt != null) {
          type = "recursive";
          source = attempt;
        };
      }
      // listToAttrs (map (k: {
        name = "easyeffects/output/${k}.json";
        value.text = toJSON cfg.extraPresets.${k};
      }) (attrNames cfg.extraPresets));
  };
}
