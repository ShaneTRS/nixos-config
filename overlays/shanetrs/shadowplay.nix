{
  writeShellApplication,
  ffmpeg,
  gawk,
  gpu-screen-recorder,
  libnotify,
  losslesscut-bin,
  util-linux,
  xclip,
  xdpyinfo,
  targetDir ? "$HOME/Videos/ShadowPlay",
  ...
}:
writeShellApplication rec {
  name = "shadowplay";
  runtimeInputs = [
    ffmpeg
    gawk
    gpu-screen-recorder
    libnotify
    losslesscut-bin
    util-linux
    xclip
    xdpyinfo
  ];
  text = ''
    set +uo errexit
    WORK_DIR="/tmp/${name}-bc2c0893"
    TARGET_DIR="${targetDir}"

    mkdir -p "$WORK_DIR"
    exec 3<>"$WORK_DIR/.lock"

    PID="$(flock -n 3 || cat "$WORK_DIR/.lock")";

    kill -0 "$PID" 2>/dev/null && case "$1" in
      clip) exec kill -USR1 "$PID" ;;
      stop) exec kill "$PID" ;;
      *) kill "$PID" ;;
    esac
    [ -n "$1" ] && exit 2

    notify () {
      case "$(notify-send -t 15000 -i media-record -a shadowplay -A "Show replays" "$@")" in
        0) xdg-open "$TARGET_DIR" ;; # show replays
        1) losslesscut --settings-json "{customOutDir:\"$WORK_DIR\"}" -- "$OUT" # trim replay
          NOTIFICATION=$(notify-send -t 60000 -i media-record -a shadowplay "Transcoding file" "Please wait for the transcode to complete." -p)
          sleep 0.7
          TRIM="$(basename "''${OUT%.*}")_Trim.''${OUT##*.}"
          if [ -f "$WORK_DIR/$TRIM" ]; then
            xclip -sel c -t text/uri-list <<< "file://$TARGET_DIR/$TRIM"
            ffmpeg -threads 2 -i "$WORK_DIR/$TRIM" -vf "scale=trunc(iw/3)*2:trunc(ih/3)*2:flags=lanczos" -movflags faststart \
              -crf 28 -preset veryslow -c:a libopus -ac 1 -b:a 48k "$TARGET_DIR/$TRIM";
            notify "Transcoding complete" "The clip has been copied to the clipboard." -r "$NOTIFICATION"
          else
            notify "Trimming cancelled" "The full clip has been copied to the clipboard" -r "$NOTIFICATION"
          fi
        ;;
        2) rm "$OUT" ;; # delete replay
      esac &
    }

    flock 3
    notify "Started recording to RAM" "Execute '${name} clip' to save the last 2 minutes to disk."

    RES="$(xdpyinfo|awk '/dimensions:/{print $2}')"
    gpu-screen-recorder -o "$TARGET_DIR" -v no -w focused -s "$RES" -c mp4 \
      -f 30 -fm vfr -r 120 -q medium -k h264 -a 'default_input|default_output' -ac opus > >(
        while read -r OUT; do
          echo "- $OUT"
          xclip -sel c -t text/uri-list <<< "file://$OUT"
          notify "Saved recording to disk" "''${OUT##*/}" -A "Trim replay" -A "Delete replay"
        done
      ) & PID=$!
    echo "$PID" >&3; wait "$PID"

    notify "Stopped recording to RAM" "The screen recording backend is no-longer running."
    flock -u 3
  '';
}
