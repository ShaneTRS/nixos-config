{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) escapeShellArgs getExe mkEnableOption mkIf mkOption mkPackageOption optionalString types;
  inherit (lib.tundra) resolveList;
  cfg = config.shanetrs.hardware.iio-sensors;
in {
  options.shanetrs.hardware.iio-sensors = {
    enable = mkEnableOption "IIO sensor services for automatic rotation and brightness";
    package = mkPackageOption pkgs "iio-sensor-proxy" {};
    args = mkOption {
      type = types.listOf types.str;
      default = resolveList [
        (mkIf (cfg.accel.enable != false) "--accel")
        (mkIf cfg.light.enable "--light")
      ];
    };
    light = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      command = mkOption {
        type = types.listOf types.str;
        default = [(getExe pkgs.brightnessctl) "--class=backlight" "set"];
      };
    };
    accel = {
      enable = mkOption {
        type = types.enum [true "vertical" false];
        default = true;
      };
      command = mkOption {
        type = types.listOf types.str;
        default = [(getExe pkgs.xrandr) "--current" "--orientation"];
      };
    };
  };

  config = mkIf cfg.enable {
    hardware.sensor.iio = {
      enable = true;
      inherit (cfg) package;
    };
    systemd.user.services.iio-sensors = let
      skipVert = optionalString (cfg.accel.enable == "vertical") "continue;";
    in {
      script = ''
        set +o errexit
        accel() {
          [[ "''${LAST_ACCEL[@]}" != "$@" ]] &&
            ${escapeShellArgs cfg.accel.command} "$@";
          LAST_ACCEL="$@"
        }
        calc() {
          local result="$(${getExe pkgs.bc} <<< "scale=3; $@")"
          echo "$result"
          [[ "$result" = "1" ]]
        }
        s_calc() { calc "$@" >/dev/null; }
        ${getExe cfg.package} ${escapeShellArgs cfg.args} | while read -r -a line; do
          case "''${line[@]}" in
            *"Accelerometer orientation changed"*)
              case "''${line[-1]}" in
                normal) accel normal ;;
                bottom-up) accel inverted ;;
                left-up) ${skipVert} accel left ;;
                right-up) ${skipVert} accel right ;;
              esac
            ;;
            *"Light changed"*)
              LIGHT="''${line[-2]}"
              REL_LIGHT="$(calc "(1 - ''${LAST_LIGHT:-$LIGHT} / $LIGHT) * 100")"
              LAST_LIGHT="''${line[-2]}"
              ${escapeShellArgs cfg.light.command} "$(s_calc "$REL_LIGHT < 0" && echo "''${REL_LIGHT#-}%-" || echo "$REL_LIGHT%+")"
            ;;
          esac
        done
      '';
      wantedBy = ["graphical-session.target"];
    };
  };
}
