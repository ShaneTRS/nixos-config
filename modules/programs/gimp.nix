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

  nixos = mkIf cfg.enable {
    services.gvfs = {
      enable = true; # virtual mounts daemon
      package = cfg.gvfs.package;
    };
  };

  home = mkIf cfg.enable {
    home.packages = [cfg.package];
  };
}
