{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption mkPackageOption types;
  cfg = config.shanetrs.programs.gimp;
in {
  options.shanetrs.programs.gimp = {
    enable = mkEnableOption "GIMP configuration and services";
    package = mkPackageOption pkgs "gimp3-with-plugins" {};
    gvfs = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      package = mkOption {
        type = types.package;
        default = pkgs.gnome.gvfs;
      };
    };
  };

  config = mkIf cfg.enable {
    shanetrs.desktop.mime.default = {
      "image/jpeg" = ["gimp.desktop"];
      "image/png" = ["gimp.desktop"];
      "image/webp" = ["gimp.desktop"];
      "image/x-xcf" = ["gimp.desktop"];
    };
    tundra.packages = [cfg.package];
    services.gvfs = {
      enable = true; # virtual mounts daemon
      package = cfg.gvfs.package;
    };
  };
}
