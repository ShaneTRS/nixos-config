{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) elem;
  inherit (lib) mkEnableOption mkOption types mkIf;
  cfg = config.shanetrs.gaming.vr;
in {
  options.shanetrs.gaming.vr = {
    enable = mkEnableOption "VR configuration and drivers";
    headsets = mkOption {
      type = types.listOf (types.enum ["quest2"]);
      default = [];
    };
    features = mkOption {
      type = types.listOf (types.enum ["sst" "camera-fbt" "sidequest"]);
      default = ["sst"];
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
    };
  };

  config = mkIf cfg.enable {
    programs.alvr.enable = mkIf (cfg.headsets == "oculus") true; # TODO: declarative configuration
    tundra.packages = with pkgs;
      cfg.extraPackages
      ++ [
        # (mkIf (elem "camera-fbt" cfg.features) shanetrs.camera-fbt)
        (mkIf (elem "sidequest" cfg.features) sidequest)
        # (mkIf (elem "sst" cfg.features) shanetrs.shanetrs-sst)
      ];
  };
}
