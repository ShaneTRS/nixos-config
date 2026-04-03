{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkPackageOption;
  pcfg = config.shanetrs.shell;
  cfg = pcfg.features.zoxide;
  enabled = pcfg.enable && cfg.enable;
in {
  options.shanetrs.shell.features.zoxide = {
    enable = mkEnableOption "Install and configure fastfetch to preferences";
    package = mkPackageOption pkgs "zoxide" {};
  };

  config = mkIf enabled {
    shanetrs.shell = {
      shared.aliases = {
        ccd = "builtin cd";
      };
      features.fzf.enable = true;
    };
    programs.zoxide = {
      enable = true;
      flags = ["--cmd cd"];
      inherit (cfg) package;
    };
  };
}
