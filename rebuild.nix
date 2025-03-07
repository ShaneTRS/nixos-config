{
  pkgs,
  shellDeps,
  machine,
  ...
}:
pkgs.writeShellApplication {
  name = "flake-rebuild";
  runtimeInputs = shellDeps;
  text = ''
    set +uo errexit

    SRC="${machine.source}"
    INTERACTIVE=''${INTERACTIVE:-true}
    COMMIT=''${COMMIT:-true}
    UPDATE=''${UPDATE:-false}

    cd "$SRC"

    # shellcheck disable=SC2094 disable=SC2317
    jq_write() { jq ".''${*:2}" <<< "$(cat "$1")" > "$1"; }
    # shellcheck disable=SC2317
    try_exe() { type "$1" &> /dev/null && exec "$@"; }

    # shellcheck disable=SC2317
    as_root() {
    	try_exe doas "$@" ||
     	try_exe sudo "$@" ||
      try_exe su root -c "$@"
    }

    if [ -z "$(jq .serial machine.json -r)" ]; then
    	echo Serial number is missing! Grabbing from system..
      SERIAL=$(as_root cat /sys/devices/virtual/dmi/id/board_serial || exit)
      jq_write machine.json serial = "\"$SERIAL\""
      # shellcheck disable=SC2016 disable=SC2091
      $(jq '."$defs".serials.enum|any(.=="'"$SERIAL"'")' schema.json) ||
      	jq_write schema.json '"$defs".serials.enum' += "[\"$SERIAL\"]"
      HW_CONF="hardware/$SERIAL.nix"
      if ! [[ -f "$HW_CONF" || -d "hardware/$SERIAL" ]]; then
        printf "# %s (%s)\n{ }\n" \
          "$(cat /sys/devices/virtual/dmi/id/product_name)" \
          "$(cat /sys/devices/virtual/dmi/id/product_version)" > "$HW_CONF"
        echo "Hardware config is missing! The build will fail."
        exit 1
      fi
      "''${EDITOR:-nano}" "$SRC/machine.json"
    fi

    track() {
      if [ "$1" == "add" ]; then
        git update-index --really-refresh "''${@:2}"
      elif [ "$1" == "rm" ]; then
        git restore --staged "''${@:2}"
        git update-index --assume-unchanged --skip-worktree "''${@:2}"
      fi
    }

    update-repo() {
      git add -A; git update-index --refresh >/dev/null
      git diff-index --quiet HEAD -- ||
        git commit -am "AUTO: Configuration updated"
    }

    if ! git diff-index --quiet HEAD -- &&
      $COMMIT && $INTERACTIVE && ! git diff --color-words |
        awk '!/--- a|+++ b|index [0-9a-z]{6}/ {print $0}' | less -RK;
    then
      echo "Cancelled configuration update";
      exit 1
    fi

    with_nom() { "$@" --log-format internal-json 2>&1 | nom --json && BUILD=true; }

    $UPDATE && nix flake update
    IFS=: read -ra SKIP <<< "$SKIP"
    track add machine.json "''${SKIP[@]}"
    if [ "$1" != "copy" ]; then
      with_nom as_root nixos-rebuild "$@" --flake "git+file://$SRC?submodules=1#default"
    else
      "''${EDITOR:-nano}" machine.json
      TARGET="''${TARGET:-$2}"
      with_nom nix build "git+file://$SRC?submodules=1#nixosConfigurations.default.config.system.build.toplevel"
      [[ $BUILD && -n "$TARGET" ]] &&
      nix-copy-closure --to "$TARGET" ./result \
      	--log-format internal-json 2>&1 | nom --json
    fi
    track rm machine.json "''${SKIP[@]}"

    $COMMIT && $BUILD && [ ! "$1" = "test" ] && update-repo

    exit 0
  '';
}
