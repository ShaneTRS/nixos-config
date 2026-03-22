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
        nix-shell() {
          local args=() option
          for i in "$@"; do
            if [[ -n $option || $i[1] = - ]]; then
              args+=($i) option=1
              continue
            fi
            args+=("pkgs#$i")
          done
          IN_NIX_SHELL=impure NIXPKGS_ALLOW_UNFREE=1 nix shell --impure "''${args[@]}"
        }
        nix-inspect() {
          local dirs=() parse target
          if [ -n "$1" ]; then
            parse=("$(nix build --print-out-paths --no-link "pkgs#$1")/bin")
          else
            parse=($(sed 's/:/\n/g' <<< "$PATH"))
          fi
          for i in "''${parse[@]}"; do
            [ "''${i::10}" = /nix/store ] || continue
            dirs+=("$i")
          done
          if [ "''${#parse[@]}" -eq 1 ]; then
            target="''${parse[@]}"
          else
            ${
          if pcfg.features.fzf.enable
          then ''target="$(printf '%s\n' "''${dirs[@]}" | fzf)"''
          else ''
            select target in "''${dirs[@]}"; do
              [ -n "$target" ] && break
            done
          ''
        }
          fi
          (cd "$target/.."; exec "''${SHELL:-bash}")
        }
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
          command_not_found_handler() {
            local cache fzf_opt match
            cache=$(awk '$1 == "'"$1"'" {print $2; exit}' "$HOME/.cache/nix-index/missing" 2>/dev/null)
            [ -d "$cache" ] || unset cache
            if [ -z "$cache" ] && [[ "$NIX_MISSING" =~ ^(auto|ask)$ ]]; then
              fzf_opt=$([ "$NIX_MISSING" = "ask" ] && echo "" || echo "-1")
              nix-locate --dry
              match=$(
                nix-locate --minimal -w --at-root "/bin/$1" 2>/dev/null |
                ${getExe pcfg.features.fzf.package} $fzf_opt -0 --height 12 --tac --footer-border double \
                --footer "$(FMT "%1%34❭❭ %37%1$1%0%37 not found! Would you like to execute it from one of the following packages?")"
              )
              unset NIX_MISSING
              if [ -n "$match" ]; then
                cache=$(nix build --print-out-paths --no-link "pkgs#$match")
                [ -n "$cache" ] && printf "%s\n%s" "$1 $cache" \
                  "$(cat "$HOME/.cache/nix-index/missing" 2>/dev/null)" > "$HOME/.cache/nix-index/missing"
              fi
            fi
            if [ -n "$cache" ]; then
              if [ "$NIX_MISSING" = ask ]; then
                FMT "%1%34❭❭ %0%1$1%0 not found! Would you like to execute %1*/''${cache:44}/bin/$1%0 instead? " >&2; read
              fi
              "$cache/bin/$1" "''${@:2}"
            else
              FMT "%1%34❭❭ %0%1$1%0 not found! Are you sure you've typed it correctly?\n" >&2
              exit 127
            fi
          }
        ''}
      '';
    };
  };
  home = mkIf enabled {
    home.sessionVariables.NIX_MISSING = pcfg.features.nix-helpers.index.missing;
  };
}
