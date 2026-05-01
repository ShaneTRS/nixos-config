{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkPackageOption mkOption types mkIf;
  cfg = config.shanetrs.gaming.lutris;
  opt = options.shanetrs.gaming.lutris;
in {
  options.shanetrs.gaming.lutris = {
    enable = mkEnableOption "Lutris configuration and installation";
    package = mkPackageOption pkgs "lutris" {};
    extraLibraries = mkOption {
      type = types.listOf types.package;
      default = [];
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
    };
  };

  config = mkIf cfg.enable {
    shanetrs.gaming.lutris = {
      extraLibraries = opt.extraLibraries.default;
      extraPackages = opt.extraPackages.default;
    };
    tundra.packages = [
      (cfg.package.override {
        extraLibraries = pkgs: cfg.extraLibraries;
        extraPkgs = pkgs: cfg.extraPackages;
      })
    ];
  };
}
