{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkPackageOption mkOption types mkIf;
  cfg = config.shanetrs.gaming.epic;
  opt = options.shanetrs.gaming.epic;
in {
  options.shanetrs.gaming.epic = {
    enable = mkEnableOption "Epic Games Launcher configuration and installation";
    package = mkPackageOption pkgs "heroic" {};
    extraPackages = mkOption {
      type = types.listOf types.package;
      example = [pkgs.legendary-gl];
      default = [];
    };
  };

  config = mkIf cfg.enable {
    shanetrs.gaming.epic.extraPackages = opt.extraPackages.default;
    tundra.packages = cfg.extraPackages ++ [cfg.package];
  };
}
