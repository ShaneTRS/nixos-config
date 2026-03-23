{
  self ? null,
  stdenv,
  makeDesktopItem,
  writeShellApplication,
  coreutils,
  shanetrs,
  xdpyinfo,
  machine ? null,
  targetHost ?
    if self != null && machine ? id
    then self.outputs.nixosConfigurations.${machine.id}.config.shanetrs.remote.addresses.host
    else builtins.warn "targetHost is required: use .override to set it" "",
  ...
}:
stdenv.mkDerivation rec {
  name = "ml-launcher";
  desktopItem = makeDesktopItem {
    inherit name;
    desktopName = name;
    type = "Application";
    icon = "krdc";
    exec = name;
  };
  src = writeShellApplication {
    inherit name;
    runtimeInputs = [coreutils shanetrs.moonlight-qt shanetrs.not-nice xdpyinfo];
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
  };
  installPhase = ''
    install -D {$src,$out}/bin/${name}
    install -D {${desktopItem},$out}/share/applications/${name}.desktop
  '';
}
