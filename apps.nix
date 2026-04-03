{
  self,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getExe;
  inherit (pkgs) writeShellApplication;
in rec {
  default = build;
  build = {
    meta.description = "Build the relevant tundraSystem by ID";
    program = getExe (writeShellApplication {
      name = "flake-build";
      runtimeInputs = with pkgs; [openssh nix-output-monitor];
      text = ''
        INTERACTIVE="''${INTERACTIVE:-[ -t 0 ]}"
        SUDO="''${SUDO:-sudo}"

        input() {
          [ -n "''${!1:-}" ] && return
          THIS="$(eval "''${2:-}")"
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

        case "''${1:-build}" in
          boot|switch|test)
            input TUNDRA_ID
            build "$TUNDRA_ID"
            [ -z "$out" ] && return
            [ "$1" != test ] && "$SUDO" nix-env -p /nix/var/nix/profiles/system --set "$out"
            "$SUDO" "$out/bin/switch-to-configuration" "$@"
          ;;
          build)
            input TUNDRA_ID
            build "$TUNDRA_ID"
            echo "$out"
          ;;
          remote)
            input TARGET "echo ${"'\${2:-}'"}"
            input TARGET_ID "ssh '$TARGET' echo \\\$TUNDRA_ID"
            build "$TARGET_ID"
            [ -z "$out" ] && return
            nix-copy-closure --to "$TARGET" "$out"
            input TARGET_ACTION "echo '${"\${*:3}"}'"
            ssh -t "$TARGET" "$SUDO" "$out/bin/switch-to-configuration" "$TARGET_ACTION"
          ;;
        esac
        [ -n "''${out:-}" ]
      '';
    });
    type = "app";
  };
  update = {
    meta.description = "Update flake.lock and run tests";
    program = getExe (writeShellApplication {
      name = "flake-update";
      text = ''
        restore() { [ "$?" -ne 0 ] && git restore flake.lock; exit; }
        trap restore exit
        nix flake update --override-input nixpkgs-pin 'github:nixos/nixpkgs/${self.inputs.nixpkgs.rev}'
        nix flake check --no-build
        [ -z "''${TUNDRA_ID:-}" ] && exit
        "${build.program}" "''${@:-build}"
      '';
    });
    type = "app";
  };
}
