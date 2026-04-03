{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkPackageOption;
  pcfg = config.shanetrs.shell;
  cfg = pcfg.features.eza;
  enabled = pcfg.enable && cfg.enable;
in {
  options.shanetrs.shell.features.eza = {
    enable = mkEnableOption "Install and configure eza to preferences";
    package = mkPackageOption pkgs "eza" {};
  };

  config = mkIf enabled {
    shanetrs.shell.shared.aliases = {
      eza = "eza --header -o";
      ls = "eza";
      tree = "eza -T";
    };
    tundra.packages = [cfg.package];
  };
}
