{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkPackageOption mkOverride;
  cfg = config.shanetrs.shell;
  enabled = cfg.enable && cfg.features.fzf.enable;
in {
  options.shanetrs.shell.features.fzf = {
    enable = mkEnableOption "Install and configure fastfetch to preferences";
    package = mkPackageOption pkgs "fzf" {};
  };

  config = mkIf enabled {
    shanetrs.shell.bash.aliases.history-search = mkOverride 149 ''eval "$(fzf --tac < "$HISTFILE")"'';
  };

  home = mkIf enabled {
    programs.fzf = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      inherit (cfg.features.fzf) package;
    };
    home.sessionVariables.FZF_COMPLETION_TRIGGER = "#";
  };
}
