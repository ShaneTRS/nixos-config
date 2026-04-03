{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption types;
  inherit (lib.tundra) mkStrongDefault;
  cfg = config.shanetrs.shell;
in {
  options.shanetrs.shell = {
    enable = mkEnableOption "Custom configuration and tools for shells";
    default = mkOption {
      type =
        types.anything
        // {
          description = "package (or ref)";
          check = x: x == null || cfg.${x}.package or null != null;
        };
      default = null;
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
    };
    shared = {
      aliases = mkOption {
        type = types.attrsOf types.str;
        default = {};
      };
      extraRc = mkOption {
        type = types.lines;
        default = "";
      };
      binds = mkOption {
        type = types.attrs;
        default = {};
        example = {"\\es" = "history-incremental-search-backward";};
      };
    };
  };

  config = mkIf cfg.enable {
    warnings = mkIf (cfg.shared.binds != {}) ["shanetrs.shell.shared.binds doesn't do anything without an implementation!"];
    shanetrs.shell = {
      features = {
        bat.enable = mkStrongDefault true;
        eza.enable = mkStrongDefault true;
        fastfetch.enable = mkStrongDefault true;
        fd.enable = mkStrongDefault true;
        fzf.enable = mkStrongDefault true;
        nix-helpers.enable = mkStrongDefault true;
        ugrep.enable = mkStrongDefault true;
        zoxide.enable = mkStrongDefault true;
      };
      shared.aliases.less = mkStrongDefault "less -R --use-color";
    };
    users.defaultUserShell = mkIf (cfg.default != null) (cfg.${cfg.default}.package or cfg.default);
    tundra.packages = cfg.extraPackages;
  };
}
