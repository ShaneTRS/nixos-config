{
  writeShellApplication,
  gnutar,
  gnugrep,
  zstd,
  fzf,
  ...
}:
writeShellApplication rec {
  name = "backups";
  runtimeInputs = [
    gnutar
    gnugrep
    zstd
    fzf
  ];
  text = ''
    set +uo errexit

    INTERVAL="''${BACKUP_INTERVAL:-60}"
    SOURCE="''${BACKUP_SOURCE:-$PWD}"
    DIR="''${BACKUP_DIR:-$(realpath "$SOURCE/../Backups/")}"

    FULL="''${BACKUP_FULL:-date +%Y_%m}"
    INCR="''${BACKUP_INCR:-date +%d_%H%M}"

    TAR_OPTS="''${TAR_OPTS:---zstd}"
    FILE_TYPE="''${FILE_TYPE:-tar.zst}"

    backup() {
      R_FULL="$(eval "$FULL")"
      R_INCR="$(eval "$INCR")"
      ARCHIVES="''${BACKUP_ARCHIVES:-$DIR/$R_FULL/$R_FULL.archives}"
      TARGET="$DIR/$R_FULL/$R_INCR.$FILE_TYPE"
      TMP="''${BACKUP_TMP:-/tmp/${name}-$$.tmp}"

      [ -f "$TARGET" ] && return 2
      mkdir -p "$DIR/$R_FULL"
      # shellcheck disable=SC2086
      tar $TAR_OPTS --create --listed-incremental="$DIR/$R_FULL/$R_FULL.snapshot" --file="$TMP" --directory="$SOURCE" . 2>/dev/null
      if ! tar --list --listed-incremental=/dev/null --file="$TMP" | grep -v '/$' &>/dev/null; then
        rm "$TMP"
        return 1
      fi

      mv "$TMP" "$TARGET"
      echo "$TARGET" >> "$ARCHIVES"
    }

    restore() {
      R_FULL="$(eval "$FULL")"
      ARCHIVES="''${BACKUP_ARCHIVES:-$DIR/$R_FULL/$R_FULL.archives}"

      CHOICE=$(cat "$ARCHIVES" | fzf --tac)
      TARGET="''${2:-$SOURCE}"
      while read -r line; do
        tar --extract --listed-incremental=/dev/null --file="$line" --directory="$TARGET"
        [ "$line" = "$CHOICE" ] && break
      done < "$ARCHIVES"
      ls "$TARGET"
    }

    cleanup() {
      kill "$PID" 2>/dev/null
      exit
    }

    wrap() {
      trap cleanup exit
      ("$@"; kill $$) & PID=$!
      while kill -0 "$PID"; do
        sleep "$INTERVAL"
        backup && echo "[${name}] Backup saved as '$TARGET'"
      done
    }

    "$@"
  '';
}
