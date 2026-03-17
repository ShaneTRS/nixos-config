{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkPackageOption;
  cfg = config.shanetrs.shell;
  enabled = cfg.enable && cfg.features.zoxide.enable;
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
  };

  home = mkIf enabled {
    programs.zoxide = {
      enable = true;
      options = ["--cmd cd"];
      enableBashIntegration = true;
      enableZshIntegration = true;
      inherit (cfg.features.zoxide) package;
    };
  };
}
