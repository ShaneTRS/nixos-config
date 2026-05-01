{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (builtins) attrValues concatMap;
  inherit (lib) mkEnableOption mkPackageOption mkOption types mkIf;
  cfg = config.shanetrs.gaming.emulation;
  opt = options.shanetrs.gaming.emulation;
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
      example = [pkgs.shanetrs.schud];
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
      package = pkgs.shanetrs.ryubing;
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
    shanetrs.gaming.emulation = {
      extraPackages = opt.extraPackages.default;
      retroarch.cores = opt.retroarch.cores.default;
    };
    tundra = {
      xdg.config = {
        "Ryujinx/bis/system/Contents/registered".source =
          mkIf (cfg.switch.package ? firmware) cfg.switch.package.firmware;
        "Ryujinx/system/prod.keys".source =
          mkIf (cfg.switch.package ? keys) "${cfg.switch.package.keys}/prod.keys";
        "Ryujinx/system/title.keys".source =
          mkIf (cfg.switch.package ? keys) "${cfg.switch.package.keys}/title.keys";
      };
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
