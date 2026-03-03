{
  pkgs,
  lib,
  ...
}: rec {
  default = rebuild;
  rebuild = {
    type = "app";
    program = lib.getExe (pkgs.writeShellApplication {
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
        try_exe() { command -v "$1" &> /dev/null && "$@"; }
        as_root() { try_exe doas "$@" || try_exe sudo "$@" || try_exe su root -c "$@"; }

        if [ "$1" = "copy" ]; then
       		TARGET="''${TARGET:-$2}"
       		TUNDRA_SERIAL="''${TARGET_SERIAL:-''${3:-$(ssh "$TARGET" echo \$TUNDRA_SERIAL)}}"
        fi
        with_nom nix build "$TUNDRA_SOURCE#nixosConfigurations.$TUNDRA_SERIAL.config.system.build.toplevel"
        [[ $BUILD && -n "$TARGET" ]] && with_nom nix-copy-closure --to "$TARGET" ./result
        [[ $BUILD && "$1" != "build" && -z "$TARGET" ]] && as_root ./result/bin/switch-to-configuration "$@"
        
        $COMMIT && $BUILD && [ "$1" != "test" ] && [ "$1" != "build" ] && update-repo

        exit 0
      '';
    });
  };
}
