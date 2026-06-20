{
  nixosConfig ? null,
  symlinkJoin,
  makeDesktopItem,
  writeShellApplication,
  gnugrep,
  shanetrs,
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
      runtimeInputs = [gnugrep shanetrs.moonlight-qt shanetrs.not-nice];
      text = ''
        APPLICATION="''${APPLICATION:-desktop}"
        TARGET="''${TARGET:-${targetHost}}"

        if [ -z "$TARGET" ]; then
         	echo 'TARGET: parameter not set' 1>&2
          exit 2
        fi

        start() {
          coproc STREAMER { exec not-nice moonlight stream "$TARGET" "$APPLICATION" "$@" 2>&1; }
          while read -r line; do
            echo "$line"
            case "$line" in
              *"Quit event received"*)
                return 0 ;;
              *"Connection terminated"*)
                stop; return 1 ;;
              *"Failed to connect"*)
                stop; return 2 ;;
            esac
          done <& "''${STREAMER[0]}"
        }
        stop() { [ -z "$STREAMER_PID" ] || kill "$STREAMER_PID"; }

        while true; do
          if start "$@"; then break; fi
          sleep 1
        done
      '';
    })
  ];
}
