{
  self,
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
        openssh
        nix-output-monitor
      ];
      text = ''
        set +uo errexit

        INTERACTIVE="''${INTERACTIVE:-[ -t 0 ]}"
        SUDO="''${SUDO:-sudo}"

        input() {
          [ -n "''${!1}" ] && return
          THIS="$(eval "$2")"
          if [ -n "$THIS" ]; then
            read -r "$1" <<< "$THIS"
          elif eval "$INTERACTIVE"; then
            read -rp "$1: " "$1"
          else
            echo "$1: parameter not set" 1>&2
            exit 2
          fi
        }

        build() { out="$(nom build --print-out-paths --no-link "${self}#nixosConfigurations.$1.config.system.build.toplevel")"; }

        case "$1" in
          boot|switch|test)
            input TUNDRA_ID
            build "$TUNDRA_ID"
            [ -z "$out" ] && return
            "$SUDO" "$out/bin/switch-to-configuration" "$@"
          ;;
          build)
            input TUNDRA_ID
            build "$TUNDRA_ID"
            echo "$out"
          ;;
          remote)
            input TARGET "echo '$2'"
            input TARGET_ID "ssh '$TARGET' echo \\\$TUNDRA_ID"
            build "$TARGET_ID"
            [ -z "$out" ] && return
            nix-copy-closure --to "$TARGET" "$out"
            input TARGET_ACTION "echo \"''${*:3}\""
            # shellcheck disable=SC2029
            ssh -t "$TARGET" "$SUDO" "$out/bin/switch-to-configuration" "$TARGET_ACTION"
          ;;
        esac
      '';
    });
  };
}
