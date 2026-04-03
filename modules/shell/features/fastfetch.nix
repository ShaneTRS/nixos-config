{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) fromJSON readFile toJSON;
  inherit (lib) mkIf mkEnableOption mkPackageOption recursiveUpdate;
  inherit (lib.tundra) mkIfConfig;
  pcfg = config.shanetrs.shell;
  cfg = pcfg.features.fastfetch;
  enabled = pcfg.enable && cfg.enable;
in {
  options.shanetrs.shell.features.fastfetch = {
    enable = mkEnableOption "Install and configure fastfetch to preferences";
    package = mkPackageOption pkgs "fastfetch" {};
  };

  config = mkIf enabled {
    tundra = {
      xdg.config."fastfetch/config.jsonc" = mkIfConfig "fastfetch.jsonc" (x: {
        text = toJSON (recursiveUpdate (fromJSON (readFile x)) {
          logo.source = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
        });
      });
      # TODO: setup fontconfig
      packages = [
        pkgs.nerd-fonts.hack
        (cfg.package.overrideAttrs (old: {
          cmakeFlags = ["-DENABLE_IMAGEMAGICK7=true"] ++ old.cmakeFlags or [];
        }))
      ];
    };
  };
}
