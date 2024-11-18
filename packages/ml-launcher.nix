{ pkgs, lib, hosts ? self.outputs.nixosConfigurations.default.config.shanetrs.remote.addresses.host, self, ... }:
let
  inherit (builtins) elemAt;
  inherit (lib) concatStringsSep;
  inherit (pkgs) writeShellApplication;
in writeShellApplication {
  name = "ml-launcher";
  runtimeInputs = with pkgs; [ coreutils local.addr-sort local.moonlight-qt xorg.xdpyinfo ];
  text = ''
    ml_res () { xdpyinfo | awk '/dimensions/{print $2}'; }
    ml_target () { addr-sort ${concatStringsSep " " hosts}; }
    ml_bitrate () {
      [ "$1" == "${elemAt hosts 0}" ] && exec echo 65000
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
}
