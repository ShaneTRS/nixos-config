{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkPackageOption mkOption types mkIf;
  cfg = config.shanetrs.gaming.epic;
in {
  options.shanetrs.gaming.epic = {
    enable = mkEnableOption "Epic Games Launcher configuration and installation";
    package = mkPackageOption pkgs "heroic" {};
    extraPackages = mkOption {
      type = types.listOf types.package;
      example = with pkgs; [legendary-gl];
      default = [];
    };
  };

  config = mkIf cfg.enable {
    tundra.packages = cfg.extraPackages ++ [cfg.package];
  };
}
