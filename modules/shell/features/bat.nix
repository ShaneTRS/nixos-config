{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkPackageOption;
  pcfg = config.shanetrs.shell;
  cfg = pcfg.features.bat;
  enabled = pcfg.enable && cfg.enable;
in {
  options.shanetrs.shell.features.bat = {
    enable = mkEnableOption "Install and configure bat to preferences";
    package = mkPackageOption pkgs "bat" {};
  };

  config = mkIf enabled {
    shanetrs.shell.shared.aliases = {
      cat = "bat";
      ccat = "command cat";
    };
    programs.bat = {
      enable = true;
      inherit (cfg) package;
    };
  };
}
