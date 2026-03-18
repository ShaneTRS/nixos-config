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
      };
    };
  };

  nixos = mkIf enabled {
    users.defaultUserShell = mkOverride 999 cfg.zsh.package;
    programs.zsh = {
      enable = true;
      autosuggestions.enable = true;
      histSize = 16384;
      promptInit = extraRc;
    };
  };

  home = mkIf cfg.enable {
    home.packages = [pkgs.zsh-completions];
    programs.zsh = {
      enable = true;
      dotDir = "${config.xdg.configHome}/zsh";
      historySubstringSearch.enable = true;
      history = {
        ignorePatterns = ["exit"];
        path = "${config.xdg.configHome}/zsh/zsh_history";
        size = 16384;
      };
      initContent = extraRc;
      shellAliases = cfg.shared.aliases // cfg.bash.aliases;
      syntaxHighlighting = {
        enable = true;
        highlighters = ["brackets"];
      };
    };
  };
}
