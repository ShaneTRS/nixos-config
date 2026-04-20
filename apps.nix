{
  self,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getExe;
  inherit (pkgs) writeShellApplication;
  nixArgs = "--extra-experimental-features 'flakes nix-command'";
in rec {
  default = build;
  build = {
    meta.description = "Build the relevant tundraSystem by ID";
    program = getExe (writeShellApplication {
      name = "flake-build";
      runtimeInputs = with pkgs; [coreutils openssh nix-output-monitor nixVersions.latest];
      text = ''
        INTERACTIVE="''${INTERACTIVE:-[ -t 0 ]}"
        SUDO="''${SUDO:-sudo}"

        build() {
          out="$(nom build ${nixArgs} --no-link --print-out-paths \
            "${self}#nixosConfigurations.$1.config.system.build.''${2:-toplevel}")"
          echo "$out"
        }
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

        run() { case "''${1:-build}" in
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
          ;;
          remote)
            input TARGET "echo ${"'\${2:-}'"}"
            input TARGET_ID "ssh '$TARGET' echo \\\$TUNDRA_ID"
            build "$TARGET_ID"
            [ -z "$out" ] && return
            nix-copy-closure --to "$TARGET" "$out"
            input TARGET_ACTION "echo '${"\${*:3}"}'"
            [ "$TARGET_ACTION" = build ] && return
            ssh -t "$TARGET" "$SUDO" "/bin/sh -c '
              $([ "$TARGET_ACTION" != test ] && echo "nix-env -p /nix/var/nix/profiles/system --set $out")
              $out/bin/switch-to-configuration $TARGET_ACTION
            '"
          ;;
          vm)
            input TARGET_ID "echo ${"'\${2:-}'"}"
            build "$TARGET_ID" "''${TARGET_TYPE:-vm}"
            [ -z "$out" ] && return
            vm=("$out/bin/run-"*"-vm")
            export TMPDIR="''${TMPDIR:-/tmp/nix-vm.$TARGET_ID}"
            export USE_TMPDIR=1 NIX_DISK_IMAGE="$TMPDIR/root.qcow2"
            mkdir -p "$TMPDIR"
            "''${vm[0]}" -display gtk,grab-on-hover=on,zoom-to-fit=on "''${@:3}"
          ;;
        esac; }

        run "$@"; [ -n "''${out:-}" ]
      '';
    });
    type = "app";
  };
  update = {
    meta.description = "Update flake.lock and run tests";
    program = getExe (writeShellApplication {
      name = "flake-update";
      runtimeInputs = with pkgs; [git nixVersions.latest];
      text = ''
        trap '[ "$?" -ne 0 ] && git restore flake.lock; exit' exit
        nix ${nixArgs} flake update --override-input nixpkgs-pin 'github:nixos/nixpkgs/${self.inputs.nixpkgs.rev}'
        nix ${nixArgs} flake check --no-build
        [ -z "''${TUNDRA_ID:-}" ] && exit
        "${build.program}" "''${@:-build}"
      '';
    });
    type = "app";
  };
}
