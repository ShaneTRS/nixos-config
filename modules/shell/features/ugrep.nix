{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkPackageOption;
  cfg = config.shanetrs.shell;
  enabled = cfg.enable && cfg.features.ugrep.enable;
in {
  options.shanetrs.shell.features.ugrep = {
    enable = mkEnableOption "Install and configure fastfetch to preferences";
    package = mkPackageOption pkgs "ugrep" {};
  };

  config = mkIf enabled {
    shanetrs.shell.shared.aliases = {
      grep = "ugrep";
    };
  };

  home = mkIf enabled {
    home.packages = [cfg.features.ugrep.package];
  };
}
