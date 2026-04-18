{
  symlinkJoin,
  writeShellApplication,
  dbus,
  git,
  libnotify,
  ...
}:
symlinkJoin rec {
  name = "tundra";
  paths = [
    ./src
    (writeShellApplication {
      inherit name;
      runtimeInputs = [dbus git libnotify];
      text = ''
        SUDO="''${SUDO:-sudo}"

        # shellcheck disable=SC2120
        garbage() {
          local cmd="nix-collect-garbage ''${*:---delete-older-than ''${TIME:-30d}}"
          echo "executing: $cmd" 1>&2
          # shellcheck disable=SC2086
          "$SUDO" $cmd || exit 1; $cmd
        }

        rebuild() {
          nix run "$TUNDRA_SOURCE#build" -- "''${@:-boot}"
        }

        help() {
        	cat <<-EOF
        	Usage: $(basename "$0") <command>
        	Commands:
        	  garbage    Run garbage collection on the Nix store
        	  rebuild    Rebuild system with current configuration
        	EOF
        }

        cd "$TUNDRA_SOURCE" || exit 1
        "''${@:-help}"
      '';
    })
  ];
}
