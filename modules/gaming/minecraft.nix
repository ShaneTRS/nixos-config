{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkPackageOption mkOption types mkIf;
  cfg = config.shanetrs.gaming.minecraft;
  opt = options.shanetrs.gaming.minecraft;
in {
  options.shanetrs.gaming.minecraft = {
    enable = mkEnableOption "Minecraft configuration and installation";
    package = mkPackageOption pkgs "prismlauncher" {};
    java = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [temurin-jre-bin-25 temurin-jre-bin temurin-jre-bin-8];
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      example = [pkgs.flite];
      default = [];
    };
  };

  config = mkIf cfg.enable {
    shanetrs.gaming.minecraft.extraPackages = opt.extraPackages.default;
    tundra.packages =
      cfg.extraPackages
      ++ [(cfg.package.override {jdks = cfg.java;})];
  };
}
