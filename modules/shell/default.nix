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
      type = types.nullOr types.package;
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
  };

  nixos = mkIf cfg.enable {
    users.defaultUserShell = mkIf (cfg.default != null) cfg.default;
  };

  home = mkIf cfg.enable {
    home.packages = cfg.extraPackages;
  };
}
