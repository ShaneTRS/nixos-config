{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) getExe mkIf mkEnableOption mkPackageOption mkOverride;
  pcfg = config.shanetrs.shell;
  cfg = pcfg.features.fzf;
  enabled = pcfg.enable && cfg.enable;
in {
  options.shanetrs.shell.features.fzf = {
    enable = mkEnableOption "Install and configure fastfetch to preferences";
    package = mkPackageOption pkgs "fzf" {};
  };

  config = mkIf enabled {
    shanetrs.shell = {
      bash = {
        aliases.history-search = mkOverride 149 ''eval "$(fzf --tac < "$HISTFILE")"'';
        extraRc = ''
          [[ :$SHELLOPTS: =~ :(vi|emacs): ]] && eval "$(${getExe cfg.package} --bash)"
        '';
      };
      zsh.extraRc = ''
        [[ $options[zle] = on ]] && source <(${getExe cfg.package} --zsh)
      '';
    };
    tundra = {
      packages = [cfg.package];
      environment.variables.FZF_COMPLETION_TRIGGER = "#";
    };
  };
}
