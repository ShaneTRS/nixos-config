{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkPackageOption mkOption types mkIf;
  cfg = config.shanetrs.gaming.gamescope;
in {
  options.shanetrs.gaming.gamescope = {
    enable = mkEnableOption "Gamescope configuration and installation";
    package = mkPackageOption pkgs "gamescope" {};
    args = mkOption {
      type = types.listOf types.str;
      default = ["--rt"];
    };
    env = mkOption {
      type = types.attrsOf types.str;
      default = {};
    };
  };

  nixos = mkIf cfg.enable {
    programs.gamescope = {
      inherit (cfg) enable args env package;
      capSysNice = false; # doesn't work in fhs when true
    };
  };
}
