{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "shadowplay";
  runtimeInputs = with pkgs; [ gpu-screen-recorder libnotify losslesscut-bin pulseaudio ];
  text = ''
    notify () {
      # shellcheck disable=SC2207
      replay=($(ls "$dir" --sort=time -1))
      # shellcheck disable=SC2128
      case "$(notify-send -i media-record -a shadowplay -A "Show replays" "$@")" in
        0) xdg-open "$dir"
          # shellcheck disable=SC2104
          break ;;
        1) xclip -sel c -t text/uri-list <<< "file://''${line%.*}_Trim.''${line##*.}"
          # shellcheck disable=SC2128
          losslesscut "$dir/$replay"
          # shellcheck disable=SC2104
          break ;;
        2) rm "$dir/$replay"
          # shellcheck disable=SC2104
          break ;;
      esac;
    }
    refresh () { pkill -P $$; exec $0; }

    trap "refresh" USR1
    dir="$HOME/Videos/ShadowPlay"
    mkdir -p "$dir"
    comm="gpu-screen-recorder -o $dir -v no \
    -w focused -s 1366x768 -c mp4 -f 30 -fm vfr -r 120 -q medium -k h264 \
    -a $(pactl get-default-sink).monitor -ac opus"

    if [ -n "''${1:-}" ]; then
      [[ "$1" == "clip" ]] && exec pkill -f "$comm" -USR1
    fi

    echo "$comm" # Make sure this matches the formatting of /proc/#/cmdline
    notify "Started recording to RAM" "Press Ctrl+Alt+Shift+S to save the last 2 minutes to disk."
    exec $comm | while read -r line; do
      xclip -sel c -t text/uri-list <<< "file://$line"
      notify "Saved recording to disk" "''${line##*/}" -A "Trim replay" -A "Delete replay"
    done & wait
    notify "Stopped recording to RAM" "The screen recording backend is no-longer running."
  '';
}
