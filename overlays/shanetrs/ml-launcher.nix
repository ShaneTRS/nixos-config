{
  nixosConfig ? null,
  symlinkJoin,
  makeDesktopItem,
  writeShellApplication,
  coreutils,
  gawk,
  shanetrs,
  xdpyinfo,
  targetHost ? nixosConfig.shanetrs.remote.addresses.host or
    (builtins.warn "targetHost is required: use .override to set it" ""),
  ...
}:
symlinkJoin rec {
  name = "ml-launcher";
  paths = [
    (makeDesktopItem {
      inherit name;
      desktopName = name;
      type = "Application";
      icon = "krdc";
      exec = name;
    })
    (writeShellApplication {
      inherit name;
      runtimeInputs = [coreutils gawk shanetrs.moonlight-qt shanetrs.not-nice xdpyinfo];
      text = ''
        ml_res() { xdpyinfo | awk '/dimensions/{print $2}'; }
        ml_args() {
          echo "$APPLICATION" --resolution "$RESOLUTION" --fps "$FPS" --bitrate "$BITRATE" \
            --audio-on-host --quit-after --game-optimization --multi-controller \
            --background-gamepad --capture-system-keys always \
            --video-codec HEVC --video-decoder hardware --no-vsync
        }
        RESOLUTION="''${RESOLUTION:-$(ml_res)}"
        TARGET="''${TARGET:-${targetHost}}"
        if [ -z "$TARGET" ]; then
         	echo 'TARGET: parameter not set' 1>&2
          exit 2
        fi
        PORT="''${PORT:-47989}"
        BITRATE="''${BITRATE:-65000}"
        FPS="''${FPS:-62}"
        APPLICATION="''${APPLICATION:-desktop}"
        ARGS="''${ARGS:-$(ml_args)}"
        COMMAND="not-nice moonlight stream "$TARGET:$PORT" ''${ARGS[*]} $*"
        echo "Connecting to $TARGET at $RESOLUTION!"
        if [ -n "''${DEBUG:-}" ]; then
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
    })
  ];
}
