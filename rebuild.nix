{pkgs, ...}:
pkgs.writeShellApplication {
  name = "flake-rebuild";
  runtimeInputs = with pkgs; [
    coreutils
    gawk
    git
    nixos-rebuild
    nix-output-monitor
  ];
  text = ''
    set +uo errexit

    INTERACTIVE=''${INTERACTIVE:-true}
    COMMIT=''${COMMIT:-true}
    UPDATE=''${UPDATE:-false}

    input() { $INTERACTIVE || exit 1; [ -z "''${!1}" ] && read -rp "$1: " "$1"; }

    input TUNDRA_SOURCE
    input TUNDRA_SERIAL

    cd "$TUNDRA_SOURCE" || exit

    update-repo() {
      git add -A; git update-index --refresh >/dev/null
      git diff-index --quiet HEAD -- ||
        git commit -am "AUTO: Configuration updated"
    }

    if ! git diff-index --quiet HEAD -- &&
      $COMMIT && $INTERACTIVE && [ ! "$1" = "test" ] && ! git diff --color-words |
        awk '!/--- a|+++ b|index [0-9a-z]{6}/ {print $0}' | less -RK;
    then
      echo "Cancelled configuration update";
      exit 1
    fi

    with_nom() { "$@" --log-format internal-json 2>&1 | nom --json && BUILD=true; }

    $UPDATE && nix flake update
    if [ "$1" != "copy" ]; then
    	with_nom nixos-rebuild "$@" --flake "git+file://$TUNDRA_SOURCE?submodules=1#$TUNDRA_SERIAL" -S
    else
    	TARGET_SERIAL="''${TARGET_SERIAL:-$3}"
      TARGET="''${TARGET:-$2}"
      with_nom nix build "git+file://$TUNDRA_SOURCE?submodules=1#nixosConfigurations.\"$TARGET_SERIAL\".config.system.build.toplevel"
      [[ $BUILD && -n "$TARGET" ]] && with_nom nix-copy-closure --to "$TARGET" ./result
    fi

    $COMMIT && $BUILD && [ ! "$1" = "test" ] && update-repo

    exit 0
  '';
}
