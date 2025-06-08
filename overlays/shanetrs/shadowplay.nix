{pkgs, ...}:
with pkgs;
  writeShellApplication {
    name = "shadowplay";
    runtimeInputs = [
      gawk
      gpu-screen-recorder
      libnotify
      losslesscut-bin
      pulseaudio
      xorg.xdpyinfo
    ];
    text = ''
      set +o errexit
      # shellcheck disable=SC2104 disable=2128 disable=2207
      notify () {
        replay=($(ls "$dir" --sort=time -1))
        trim="''${line%.*}_Trim.''${line##*.}"
        case "$(notify-send -i media-record -a shadowplay -A "Show replays" "$@")" in
          0) xdg-open "$dir"
            break ;;
          1) losslesscut "$dir/$replay"
            noti=$(notify-send -i media-record -a shadowplay "Transcoding file" "Please wait for the transcode to complete." -t 60 -p)
            file="$tmp_dir/$(basename "$trim")"
            sleep 0.7
            if [ -f "$file" ]; then
              xclip -sel c -t text/uri-list <<< "file://$trim"
              ffmpeg -threads 2 -i "$file" -vf "scale=trunc(iw/3)*2:trunc(ih/3)*2:flags=lanczos" -crf 28 -movflags faststart -preset veryslow -c:a libopus -ac 1 -b:a 48k "$trim";
              notify "Transcoding complete" "The clip has been copied to the clipboard." -r "$noti"
            else
              notify "Trimming cancelled" "The full clip has been copied to the clipboard" -r "$noti"
            fi
            break ;;
          2) rm "$dir/$replay"
            break ;;
        esac;
      }
      refresh () { pkill -P $$; exec $0; }

      trap "refresh" USR1
      dir="$HOME/Videos/ShadowPlay"
      tmp_dir="/tmp/shadowplay"
      mkdir -p "$tmp_dir"
      # shellcheck disable=SC2089
      comm="gpu-screen-recorder -o $dir -v no \
      -w focused -s $(xdpyinfo|awk '/dimensions:/{print $2}') -c mp4 -f 30 -fm vfr -r 120 -q medium -k h264 \
      -a \"$(pactl get-default-sink).monitor|$(pactl get-default-source)\" -ac opus"

      [[ "''${1:-}" == "clip" ]] && exec pkill -f "$comm" -USR1

      echo "$comm" # Make sure this matches the formatting of /proc/#/cmdline
      notify "Started recording to RAM" "Press Ctrl+Alt+Shift+S to save the last 2 minutes to disk." &
      eval "$comm" | while read -r line; do
        xclip -sel c -t text/uri-list <<< "file://$line"
        notify "Saved recording to disk" "''${line##*/}" -A "Trim replay" -A "Delete replay"
      done & wait
      notify "Stopped recording to RAM" "The screen recording backend is no-longer running."
    '';
  }
