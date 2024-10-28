{ config, pkgs, lib, ... }:
let inherit (lib) concatStringsSep;
in {
  services.earlyoom.enable = false;
  zramSwap.enable = false;
  programs.noisetorch.enable = true;

  shanetrs = {
    enable = true;
    browser.firefox.enable = true;
    desktop = {
      enable = true;
      session = "plasma";
    };
    remote = {
      enable = true;
      role = "client";
    };
    programs = {
      discord.enable = true;
      easyeffects.enable = true;
      vscode = {
        enable = true;
        features = [ "nix" ];
      };
    };
    shell.zsh.enable = true;
  };

  user = {
    programs.obs-studio.enable = true;
    home.packages = with pkgs; [
      gimp-with-plugins
      helvum
      jellyfin-media-player
      local.moonlight-qt
      local.spotify
      vlc
      (writeShellApplication {
        name = "moonlight-8b501";
        runtimeInputs = [ coreutils local.addr-sort xorg.xdpyinfo ];
        text = ''
          ml_res () { xdpyinfo | awk '/dimensions/{print $2}'; }
          ml_target () { addr-sort ${concatStringsSep " " config.shanetrs.remote.addresses.host}; }
          ml_bitrate () {
            [ "$1" == "10.42.0.1" ] && exec echo 65000
            echo 19000
          }
          ml_args () {
            cat <<EOF
              "$APPLICATION" --resolution "$RESOLUTION" --fps "$FPS" --bitrate "$BITRATE" \
              --audio-on-host --quit-after --game-optimization --multi-controller \
              --background-gamepad --capture-system-keys fullscreen \
              --video-codec H.264 --video-decoder hardware --no-vsync --frame-pacing
          EOF
          }

          RESOLUTION="''${RESOLUTION:-$(ml_res)}"
          TARGET="''${TARGET:-$(ml_target)}"
          PORT="''${PORT:-46989}"
          BITRATE="''${BITRATE:-$(ml_bitrate "$TARGET")}"
          FPS="''${FPS:-62}"
          APPLICATION="''${APPLICATION:-desktop}"

          ARGS="''${ARGS:-$(ml_args)}"
          COMMAND="moonlight stream "$TARGET:$PORT" ''${ARGS[*]} $*"

          echo "Connecting to $TARGET at $RESOLUTION!"
          if [ "''${DEBUG:-}" ]; then
            echo "$COMMAND"
            read -rt2
          fi
          eval "$COMMAND"
        '';
      })
      (writeShellScriptBin "backlight-8b501" ''
        export DISPLAY=:0
        mkdir -p /tmp/backlight
        processes=(`pgrep backlight-8b501`)

        max=`cat /sys/class/backlight/intel_backlight/max_brightness`
        bl_set() {
          val=$1
          echo $val
          [[ $val -gt $max ]] && val=$max
          [[ $val -lt 1 ]] && val=1
          echo "$val" > /tmp/backlight/actual_brightness
          dbus-send --session --type=method_call --dest=org.kde.Solid.PowerManagement \
            "/org/kde/Solid/PowerManagement/Actions/BrightnessControl" org.kde.Solid.PowerManagement.Actions.BrightnessControl.setBrightness int32:$val &
          true
        }
        bl_set_perc () { bl_set $((max * $1 / 100)); }
        bl_step () { bl_set $(( `cat /tmp/backlight/actual_brightness || cat /sys/class/backlight/intel_backlight/actual_brightness` + $1)); }
        bl_step_perc () { bl_step $((max * $1 / 100)); }

        [[ "$2" ]] || exit
        val=''${val:-$(( $2*''${#processes[@]} ))}
        eval "bl_$1 $val"
        sleep 0.2
      '')
    ];
  };
}
