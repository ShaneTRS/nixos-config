{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) getExe mkIf mkEnableOption mkPackageOption mkOption optionalString types;
  pcfg = config.shanetrs.shell;
  cfg = pcfg.features.nix-helpers;
  enabled = pcfg.enable && cfg.enable;

  inherit (pkgs.stdenv.hostPlatform) system;
in {
  options.shanetrs.shell.features.nix-helpers = {
    enable = mkEnableOption "Install and configure Nix helpers to preferences";
    index = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      missing = mkOption {
        type = types.enum ["auto" "ask" "never"];
        default = "auto";
      };
      package = mkPackageOption pkgs "nix-index" {};
    };
  };

  config = mkIf enabled {
    shanetrs.shell = {
      features.fzf.enable = true;
      shared.extraRc = ''
        nix-shell() {(
          ARGS=()
          for i in "$@"; do
            if [[ -n $OPTION || $i[1] = - ]]; then
              ARGS+=$i OPTION=1
              continue
            fi
            ARGS+="pkgs#$i"
          done
          IN_NIX_SHELL=impure NIXPKGS_ALLOW_UNFREE=1 nix shell --impure "''${ARGS[@]}"
        )}
        nix-inspect() { (cd $(
          PARSE='$(
            DIRS=(''${(s/:/)PATH}) PKGS=()
            for i in "''${DIRS[@]}"; do
              [[ $i =~ /nix/store ]] ||
                if [ -n "$PKGS" ]; then break; else continue; fi
              PKG=''${i::-4}
              [[ $PKGS =~ $PKG ]] || PKGS+=$PKG
            done 2> /dev/null
            [ -n "$PKGS" ] && echo "''${(j: :)PKGS}"
          )'

          PKGS=($(
            [ -z "$1" ] && exec echo ''${(e)PARSE}
             NIXPKGS_ALLOW_UNFREE=1 nix shell pkgs#$1 --command zsh -c "echo $PARSE"
          ))

          [ ''${#PKGS} = 1 ] && exec echo ''${PKGS[1]}
          PS3=""; select PKG in ''${PKGS[@]}; do
            exec echo $PKG
          done
        ) && exec "$SHELL"); }
        where() { readlink -f "$(which "$@")"; }
        ${optionalString cfg.index.enable ''
          FMT() { printf "$(sed -zE 's:%([0-9][0-9]?):\x1b[\1m:g' <<< "$@")"; }
          nix-locate() {
            if [ ! -f "$HOME/.cache/nix-index/files" ]; then
              FMT "%1%34❭❭%0 There is no database to search! Would you like to download it now? " >&2; read
              mkdir -p "$HOME/.cache/nix-index"
              ${getExe pkgs.curl} -L https://github.com/nix-community/nix-index-database/releases/latest/download/index-${system}-small \
                > "$HOME/.cache/nix-index/files"
            fi
            [ "$1" != "--dry" ] &&
              "${cfg.index.package}/bin/nix-locate" "$@"
          }
          nix-run() { NIX_MISSING=auto command_not_found_handler "$@"; }
          command_not_found_handle() { command_not_found_handler "$@"; }
          command_not_found_handler() {(
            CACHE=$(awk '$1 == "'"$1"'" {print $2; exit}' "$HOME/.cache/nix-index/missing" 2>/dev/null)
            [ -d "$CACHE" ] || unset CACHE
            if [ -z "$CACHE" ] && [[ "$NIX_MISSING" =~ ^(auto|ask)$ ]]; then
              FZF_OPT=$([ "$NIX_MISSING" = "ask" ] && echo "" || echo "-1")
              nix-locate --dry
              MATCH=$(
                nix-locate --minimal -w --at-root "/bin/$1" 2>/dev/null |
                ${getExe pcfg.features.fzf.package} $FZF_OPT -0 --height 12 --tac --footer-border double \
                --footer "$(FMT "%1%34❭❭ %37%1$1%0%37 not found! Would you like to execute it from one of the following packages?")"
              )
              unset NIX_MISSING
              if [ -n "$MATCH" ]; then
                CACHE=$(nix build --print-out-paths --no-link "pkgs#$MATCH")
                [ -n "$CACHE" ] && printf "%s\n%s" "$1 $CACHE" \
                  "$(cat "$HOME/.cache/nix-index/missing" 2>/dev/null)" > "$HOME/.cache/nix-index/missing"
              fi
            fi
            if [ -n "$CACHE" ]; then
              if [ "$NIX_MISSING" = ask ]; then
                FMT "%1%34❭❭ %0%1$1%0 not found! Would you like to execute %1*/''${CACHE:44}/bin/$1%0 instead? " >&2; read
              fi
              exec "$CACHE/bin/$1" "''${@:2}"
            else
              FMT "%1%34❭❭ %0%1$1%0 not found! Are you sure you've typed it correctly?\n" >&2
              exit 127
            fi
          )}
        ''}
      '';
    };
  };
  home = mkIf enabled {
    home.sessionVariables.NIX_MISSING = pcfg.features.nix-helpers.index.missing;
  };
}
