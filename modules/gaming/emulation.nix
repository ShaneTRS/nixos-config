{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkPackageOption mkOption types mkIf optionals resolveList;
  cfg = config.shanetrs.gaming;
in {
  options.shanetrs.gaming.emulation = {
    enable = mkEnableOption "Emulation configuration and installation";
    retroarch = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      package = mkPackageOption pkgs "retroarch" {};
      cores = mkOption {
        type = types.listOf types.package;
        default = [];
      };
    };
    nintendo = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      "3ds" = {
        enable = mkOption {
          type = types.bool;
          default = cfg.emulation.nintendo.enable;
        };
        package = mkOption {
          type = types.package;
          default = pkgs.libretro.citra;
        };
      };
      ds = {
        enable = mkOption {
          type = types.bool;
          default = cfg.emulation.nintendo.enable;
        };
        package = mkPackageOption pkgs.libretro "desmume" {};
      };
      switch = {
        enable = mkOption {
          type = types.bool;
          default = cfg.emulation.nintendo.enable;
        };
        package = mkPackageOption pkgs "ryubing" {};
        extraPackages = mkOption {
          type = types.listOf types.package;
          default = [];
        };
      };
      wii = {
        enable = mkOption {
          type = types.bool;
          default = cfg.emulation.nintendo.enable;
        };
        package = mkPackageOption pkgs.libretro "dolphin" {};
      };
      wii-u = {
        enable = mkOption {
          type = types.bool;
          default = cfg.emulation.nintendo.enable;
        };
        package = mkPackageOption pkgs "cemu" {};
        extraPackages = mkOption {
          type = types.listOf types.package;
          default = with pkgs; [evdevhook2];
        };
      };
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
    };
  };

  home = mkIf cfg.emulation.enable {
    home.packages = let
      e = cfg.emulation;
      n = e.nintendo;
      r = e.retroarch;
    in
      e.extraPackages
      ++ optionals n.wii-u.enable n.wii-u.extraPackages
      ++ optionals n.switch.enable n.switch.extraPackages
      ++ [
        (mkIf r.enable (r.package.withCores (
          cores:
            r.cores
            ++ resolveList [
              (mkIf n.ds.enable n.ds.package)
              (mkIf n."3ds".enable n."3ds".package)
              (mkIf n.wii.enable n.wii.package)
            ]
        )))
        (mkIf n.wii-u.enable n.wii-u.package)
        (mkIf n.switch.enable n.switch.package)
      ];
  };
}
