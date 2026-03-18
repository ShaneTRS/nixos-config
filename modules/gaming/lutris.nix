{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkPackageOption mkOption types mkIf;
  cfg = config.shanetrs.gaming.lutris;
in {
  options.shanetrs.gaming.lutris = {
    enable = mkEnableOption "Lutris configuration and installation";
    package = mkPackageOption pkgs "lutris" {};
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
    };
    extraLibraries = mkOption {
      type = types.listOf types.package;
      default = [];
    };
  };

  home = mkIf cfg.enable {
    home.packages = [
      (cfg.package.override {
        extraLibraries = pkgs: cfg.extraLibraries;
        extraPkgs = pkgs: cfg.extraPackages;
      })
    ];
  };
}
