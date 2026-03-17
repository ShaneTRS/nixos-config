{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOverride mkPackageOption;
  cfg = config.shanetrs.shell;
  enabled = cfg.enable && cfg.features.eza.enable;
in {
  options.shanetrs.shell.features.eza = {
    enable = mkEnableOption "Install and configure eza to preferences";
    package = mkPackageOption pkgs "eza" {};
  };

  config = mkIf enabled {
    shanetrs.shell.shared.aliases = {
      eza = mkOverride 99 "eza --header -o";
      ls = "eza";
      tree = "eza -T";
    };
  };

  home = mkIf enabled {
    programs.eza = {
      enable = true;
      inherit (cfg.features.eza) package;
    };
  };
}
