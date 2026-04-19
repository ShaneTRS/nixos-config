{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) fromJSON readFile toJSON;
  inherit (lib) mkIf mkEnableOption mkOption mkPackageOption optionalString recursiveUpdate types;
  inherit (lib.tundra) getConfig;
  inherit (pkgs) symlinkJoin writeText;
  pcfg = config.shanetrs.shell;
  cfg = pcfg.features.fastfetch;
  enabled = pcfg.enable && cfg.enable;
in {
  options.shanetrs.shell.features.fastfetch = {
    enable = mkEnableOption "Install and configure fastfetch to preferences";
    config = mkOption {
      type = types.attrsOf types.anything;
      default = let
        attempt = getConfig "fastfetch.jsonc";
      in
        if attempt != null
        then fromJSON (readFile attempt)
        else {};
    };
    fonts = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [nerd-fonts.hack];
    };
    logo = mkOption {
      type = types.nullOr types.str;
      default = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
    };
    package = mkPackageOption pkgs "fastfetch" {};
  };

  config = mkIf enabled {
    fonts = {
      fontconfig.enable = mkIf (cfg.fonts != []) true;
      packages = cfg.fonts;
    };
    tundra = {
      packages = [
        (symlinkJoin {
          name = "fastfetch-wrapped";
          paths = [cfg.package];
          preferLocalBuild = true;
          nativeBuildInputs = with pkgs; [makeWrapper];
          postBuild = optionalString (cfg.config != {}) ''
            wrapProgram $out/bin/fastfetch --add-flags '--config ${writeText "fastfetch-config.json" (toJSON (
              if cfg.logo != null
              then recursiveUpdate cfg.config {logo.source = cfg.logo;}
              else cfg.config
            ))}'
          '';
        })
      ];
    };
  };
}
