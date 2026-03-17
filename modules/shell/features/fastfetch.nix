{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) fromJSON readFile;
  inherit (lib) mkIf mkEnableOption mkPackageOption recursiveUpdate;
  inherit (lib.tundra) configs;
  cfg = config.shanetrs.shell;
  enabled = cfg.enable && cfg.features.fastfetch.enable;
in {
  options.shanetrs.shell.features.fastfetch = {
    enable = mkEnableOption "Install and configure fastfetch to preferences";
    package = mkPackageOption pkgs "fastfetch" {};
  };

  home = mkIf enabled {
    fonts.fontconfig.enable = true;
    home.packages = [pkgs.nerd-fonts.hack];
    programs.fastfetch = {
      enable = true;
      package = cfg.features.fastfetch.package.overrideAttrs (old: {
        cmakeFlags = ["-DENABLE_IMAGEMAGICK7=true"] ++ old.cmakeFlags or [];
      });
      settings = let
        attempt = configs "fastfetch.jsonc";
      in
        mkIf (attempt != null) (recursiveUpdate (fromJSON (readFile attempt)) {
          logo.source = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
        });
    };
  };
}
