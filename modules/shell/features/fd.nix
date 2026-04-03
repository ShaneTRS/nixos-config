{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkPackageOption;
  cfg = config.shanetrs.shell;
  enabled = cfg.enable && cfg.features.fd.enable;
in {
  options.shanetrs.shell.features.fd = {
    enable = mkEnableOption "Install and configure fastfetch to preferences";
    package = mkPackageOption pkgs "fd" {};
  };

  config = mkIf enabled {
    shanetrs.shell.shared.aliases = {
      fd = "fd --hidden";
    };
    tundra.packages = [cfg.features.fd.package];
  };
}
