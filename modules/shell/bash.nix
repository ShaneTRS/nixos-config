{
  options,
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) attrValues mapAttrs readFile;
  inherit (lib) concatLines mkEnableOption mkIf mkOverride mkPackageOption optionalString;
  inherit (lib.tundra) getConfig mkStrongDefault;
  cfg = config.shanetrs.shell;
  enabled = cfg.enable && cfg.bash.enable;

  extraRc =
    concatLines (
      attrValues (mapAttrs (k: v: "bind '\"${k}\":\"${v}\"'") cfg.bash.binds)
      ++ [(let attempt = getConfig ".bashrc"; in optionalString (attempt != null) (readFile attempt))]
    )
    + cfg.shared.extraRc
    + cfg.bash.extraRc;
in {
  options.shanetrs.shell.bash =
    options.shanetrs.shell.shared
    // {
      enable = mkEnableOption "Custom configuration and tools for Bash";
      package = mkPackageOption pkgs "bash" {};
    };

  config = mkIf enabled {
    shanetrs.shell.bash = mkStrongDefault {
      aliases = {
        history-search = ''tac "$HISTFILE" | less'';
      };
      binds = {
        "\\es" = "history-search\n"; # alt-s
      };
    };
    users.defaultUserShell = mkOverride 999 cfg.bash.package;
    programs.bash = {
      promptInit =
        ''
          HISTCONTROL=erasedups
          HISTFILE=${config.tundra.paths.xdg.state}/.bash_history
          HISTFILESIZE=131072
          HISTSIZE=16384
        ''
        + extraRc;
      shellAliases = cfg.shared.aliases // cfg.bash.aliases;
    };
  };
}
