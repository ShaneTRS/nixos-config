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

  home = mkIf enabled {
    programs.fd = {
      enable = true;
      hidden = true;
      inherit (cfg.features.fd) package;
    };
  };
}
