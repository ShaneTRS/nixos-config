{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkPackageOption;
  cfg = config.shanetrs.shell;
  enabled = cfg.enable && cfg.features.bat.enable;
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
  };

  home = mkIf enabled {
    programs.bat = {
      enable = true;
      inherit (cfg.features.bat) package;
    };
  };
}
