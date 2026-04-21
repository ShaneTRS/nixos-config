{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) attrValues concatMap;
  inherit (lib) mkEnableOption mkPackageOption mkOption types mkIf;
  inherit (lib.tundra) mkIfConfig;
  cfg = config.shanetrs.gaming.emulation;
in {
  options.shanetrs.gaming.emulation = let
    mkEmuOption = {
      isCore ? true,
      package,
      extraPackages ? [],
    }: {
      enable = mkOption {
        type = types.bool;
        default = cfg.enable;
      };
      isCore = mkOption {
        type = types.bool;
        default = isCore;
      };
      package = mkOption {
        type = types.package;
        default = package;
      };
      extraPackages = mkOption {
        type = types.listOf types.package;
        default = extraPackages;
      };
    };
  in {
    enable = mkEnableOption "Emulation configuration and installation";
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
    };
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

    "3ds" = mkEmuOption {package = pkgs.libretro.citra;};
    ds = mkEmuOption {package = pkgs.libretro.desmume;};
    switch = mkEmuOption {
      package = pkgs.ryubing;
      isCore = false;
    };
    wii = mkEmuOption {package = pkgs.libretro.dolphin;};
    wii-u = mkEmuOption {
      package = pkgs.cemu;
      extraPackages = [pkgs.evdevhook2];
      isCore = false;
    };
  };

  config = mkIf cfg.enable {
    tundra = {
      xdg.config."Ryujinx/system/prod.keys" = mkIfConfig "emulation/switch.keys" (x:
        mkIf cfg.switch.enable {
          source = x;
        });
      packages = let
        r = cfg.retroarch;
        emuValues = attrValues (removeAttrs cfg ["enable" "extraPackages" "retroarch"]);
      in
        cfg.extraPackages
        ++ (concatMap (x:
          if x.enable && !(x.isCore or false)
          then [x.package] ++ x.extraPackages or []
          else if x.enable
          then x.extraPackages
          else [])
        emuValues)
        ++ [
          (mkIf r.enable (r.package.withCores (cores:
            r.cores
            ++ (concatMap (x:
              if x.enable && (x.isCore or false)
              then [x.package]
              else [])
            emuValues))))
        ];
    };
  };
}
