{
  nixosConfig ? null,
  symlinkJoin,
  writeShellApplication,
  dbus,
  gawk,
  git,
  libnotify,
  nixVersions,
  nixArgs ? "--extra-experimental-features 'flakes nix-command'",
  nixPackage ? nixosConfig.nix.package or nixVersions.latest,
  ...
}:
symlinkJoin rec {
  name = "tundra";
  meta.mainProgram = name;
  paths = [
    ./src
    (writeShellApplication {
      inherit name;
      runtimeInputs = [dbus git gawk libnotify nixPackage];
      text = ''
        set +o errexit
        SUDO="''${SUDO:-sudo}"
        nix() { command nix ${nixArgs} "$@"; }

        current() { readlink /nix/var/nix/profiles/system/source | awk -F'[-/ ]+' '{print $4}' 2>/dev/null; }
        # shellcheck disable=SC2120
        garbage() {
          local cmd="nix-collect-garbage ''${*:---delete-older-than ''${TIME:-30d}}"
          echo "executing: $cmd" 1>&2
          # shellcheck disable=SC2086
          "$SUDO" $cmd || exit 1; $cmd
        }
        source() { nix flake metadata | awk -F'[-/ ]+' '/Path:/{print $4}' 2>/dev/null; }
        # shellcheck disable=SC1090
        check() { [ "$(source)" != "$(current)" ]; }
        rebuild() { nix run "$TUNDRA_SOURCE#build" -- "''${@:-boot}"; }
        sync() {
          git fetch -q &>/dev/null
          git reset --hard '@{u}' &>/dev/null
        }
        update() {
          sync; check || exit 0
          ''${GARBAGE:-true} && garbage
          rebuild "$@" &&
            [ -n "''${NOTIFY_COUNT:-}" ] &&
              notify-send -i tundra-bordered -a "Tundra: System Updater" -u critical \
              'System update complete!' 'It will be applied on next boot'
        }

        notify() {
          sync; check || exit 0
          NOTIFY_COUNT="''${NOTIFY_COUNT:-0}"
          (( NOTIFY_COUNT += 1 ))
          eval "$(notify-send -i tundra-bordered -a "Tundra: System Updater" -u critical \
            'System update available!' 'Select an option below to continue' \
            -A 'update=Install update in background' \
            -A "sleep $((''${NOTIFY_DELAY:-1200} * NOTIFY_COUNT)); notify=Ask me later" \
            -A 'exit=Ignore')"
        }

        help() {
        	cat <<-EOF
        	Usage: $(basename "$0") <command>
        	Commands:
        	  check      Returns true if current system differs from source
        	  current    Get hash of the current system
        	  garbage    Remove unused paths from the store
        	  notify     Send a notification if there is an update available
        	  rebuild    Rebuild system with current configuration
        	  source     Get system hash of ''${TUNDRA_SOURCE//~/\~}
        	  sync       Synchronize ''${TUNDRA_SOURCE//~/\~} with the remote
        	  update     Collect garbage and rebuild from source
        	EOF
        }

        export INTERACTIVE SUDO TARGET TARGET_ACTION TARGET_ID TUNDRA_ID \
          GARBAGE NOTIFY_DELAY SUDO TIME
        cd "$TUNDRA_SOURCE" || exit 1
        "''${@:-help}"
      '';
    })
  ];
}
