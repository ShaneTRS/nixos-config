{
  pkgs,
  machine ? {},
  targetHost ? self.outputs.nixosConfigurations.${machine.serial}.config.shanetrs.remote.addresses.host,
  self,
  ...
}:
with pkgs;
  pkgs.symlinkJoin rec {
    name = "ml-launcher";
    paths = [
      (
        writeShellApplication {
          inherit name;
          runtimeInputs = with pkgs; [coreutils shanetrs.moonlight-qt shanetrs.not-nice xorg.xdpyinfo];
          text = ''
            ml_res() { xdpyinfo | awk '/dimensions/{print $2}'; }
            ml_args() {
              echo "$APPLICATION" --resolution "$RESOLUTION" --fps "$FPS" --bitrate "$BITRATE" \
                --audio-on-host --quit-after --game-optimization --multi-controller \
                --background-gamepad --capture-system-keys fullscreen \
                --video-codec HEVC --video-decoder hardware --no-vsync
            }
            RESOLUTION="''${RESOLUTION:-$(ml_res)}"
            TARGET="''${TARGET:-${targetHost}}"
            PORT="''${PORT:-47989}"
            BITRATE="''${BITRATE:-65000}"
            FPS="''${FPS:-62}"
            APPLICATION="''${APPLICATION:-desktop}"
            ARGS="''${ARGS:-$(ml_args)}"
            COMMAND="not-nice moonlight stream "$TARGET:$PORT" ''${ARGS[*]} $*"
            echo "Connecting to $TARGET at $RESOLUTION!"
            if [ "''${DEBUG:-}" ]; then
              echo "$COMMAND"
              read -rt2
            fi
            while true; do
              eval "$COMMAND & pid=\$!"
              # shellcheck disable=SC2154
              until [[ "$(awk '{print $20}' "/proc/$pid/stat")" -gt 18 ]]; do
                [ -f "/proc/$pid/stat" ] || break
                sleep .6
              done
              until [[ "$(awk '{print $20}' "/proc/$pid/stat")" -lt 18 ]]; do
                [ -f "/proc/$pid/stat" ] || break
                sleep .6
              done
              kill -9 "$pid" || true
              sleep .6
            done
          '';
        }
      )
      (
        makeDesktopItem {
          inherit name;
          desktopName = name;
          type = "Application";
          icon = "krdc";
          exec = name;
        }
      )
    ];
  }
