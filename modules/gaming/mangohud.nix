{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkPackageOption mkOption types mkIf;
  cfg = config.shanetrs.gaming.mangohud;
  opt = options.shanetrs.gaming.mangohud;
in {
  options.shanetrs.gaming.mangohud = {
    enable = mkEnableOption "MangoHud configuration and installation";
    package = mkPackageOption pkgs "mangohud" {};
    settings = mkOption {
      type = types.attrs;
      default = {
        gpu_temp = 1;
        cpu_temp = 1;
        graphs = "vram,ram";
        frame_timing = 1;
        wine = 1;
        resolution = 1;
        no_display = 1;
        font_size = 19;
        position = "top-right";
        toggle_hud = "Shift_R+F12";
        toggle_fps_limit = "Shift_R+F1";
        fps_limit = "64,144";
      };
    };
  };

  config = mkIf cfg.enable {
    shanetrs.gaming.mangohud.settings = opt.settings.default;
    tundra = {
      packages = [cfg.package];
      environment.variables = {
        MANGOHUD_CONFIGFILE =
          toString (pkgs.writeText "mangohud-config.ini" (lib.generators.toINIWithGlobalSection
              {} {globalSection = cfg.settings;}));
      };
    };
  };
}
