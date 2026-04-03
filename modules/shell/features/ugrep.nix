{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkPackageOption;
  pcfg = config.shanetrs.shell;
  cfg = pcfg.features.ugrep;
  enabled = pcfg.enable && cfg.enable;
in {
  options.shanetrs.shell.features.ugrep = {
    enable = mkEnableOption "Install and configure fastfetch to preferences";
    package = mkPackageOption pkgs "ugrep" {};
  };

  config = mkIf enabled {
    shanetrs.shell.shared.aliases = {
      grep = "ugrep";
    };
    tundra.packages = [cfg.package];
  };
}
