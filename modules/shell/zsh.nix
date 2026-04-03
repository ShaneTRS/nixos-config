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
  enabled = cfg.enable && cfg.zsh.enable;

  extraRc =
    concatLines (
      attrValues (mapAttrs (key: value: ''bindkey "${key}" "${value}"'') cfg.zsh.binds)
      ++ [(let attempt = getConfig ".zshrc"; in optionalString (attempt != null) (readFile attempt))]
    )
    + cfg.shared.extraRc
    + cfg.zsh.extraRc;
in {
  options.shanetrs.shell.zsh =
    options.shanetrs.shell.shared
    // {
      enable = mkEnableOption "Custom configuration and tools for Zsh";
      package = mkPackageOption pkgs "zsh" {};
    };

  config = mkIf enabled {
    shanetrs.shell.zsh = mkStrongDefault {
      binds = {
        "^[[H" = "beginning-of-line"; # Home
        ";5H" = "beginning-of-line"; # Ctrl + Home
        ";3H" = "beginning-of-line"; # Alt + Home

        "^[[F" = "end-of-line"; # End
        ";5F" = "end-of-line"; # Ctrl + End
        ";3F" = "end-of-line"; # Alt + End

        "^[[2~" = "overwrite-mode"; # Insert

        "^[[3~" = "delete-char"; # Delete
        "5~" = "kill-word"; # Ctrl + Delete
        "3~" = "kill-word"; # Alt + Delete

        ";5C" = "forward-word"; # Ctrl + Right
        ";3C" = "forward-word"; # Alt + Right
        ";5D" = "backward-word"; # Ctrl + Left
        ";3D" = "backward-word"; # Alt + Left

        "^[[5~" = "up-line-or-history"; # Page Up
        "^[[6~" = "down-line-or-history"; # Page Down

        "^[s" = "history-incremental-search-backward"; # Alt + S

        "^[[A" = "history-substring-search-up";
        "^[[B" = "history-substring-search-down";
      };
    };
    users.defaultUserShell = mkOverride 999 cfg.zsh.package;
    programs.zsh = {
      enable = true;
      autosuggestions.enable = true;
      histSize = 131072;
      histFile = "$ZDOTDIR/zsh_history";
      shellInit = ''
        zsh-newuser-install() { :; }
        ZDOTDIR="''${HOME:-${config.tundra.paths.home}}/.config/zsh"
      '';
      promptInit =
        ''
          HISTORY_IGNORE='(exit)'
          source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh
        ''
        + extraRc;
      shellAliases = cfg.shared.aliases // cfg.zsh.aliases;
      syntaxHighlighting = {
        enable = true;
        highlighters = ["brackets"];
      };
      setOptions = [
        "HIST_FCNTL_LOCK"
        "HIST_IGNORE_DUPS"
        "HIST_IGNORE_SPACE"
        "SHARE_HISTORY"
        "NO_APPEND_HISTORY"
      ];
    };
    tundra = {
      packages = [pkgs.zsh-completions];
      xdg.config."zsh" = {
        type = "directory";
        mode = 755;
      };
    };
  };
}
