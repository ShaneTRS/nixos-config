{
  extraRc = ''
    nix-run() {
      NIXPKGS_ALLOW_UNFREE=1 nix shell --impure "pkgs#$1" \
        --command sh -c "which ''${1#*.} &>/dev/null && exec ''${1#*.} ''${*:2}; exec ''${*:2}"
    }
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
    nix-inspect() { cd $(
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
    ); }
    where() { readlink -f "$(which "$@")"; }
  '';

  nixIndex = {
    config,
    pkgs,
    ...
  }: let
    inherit (config.nixpkgs.hostPlatform) system;
  in ''
    FMT() { printf $(sed -zE 's:%([0-9][0-9]?):\x1b[\1m:g' <<< "$@") }
    nix-locate() {
      if [ ! -f "$HOME/.cache/nix-index/files" ]; then
        FMT "%1%34❭❭%0There is no database to search! Would you like to download it now? " >&2; read
        mkdir -p "$HOME/.cache/nix-index"
        ${pkgs.lib.getExe pkgs.curl} -L https://github.com/nix-community/nix-index-database/releases/latest/download/index-${system}-small \
          > "$HOME/.cache/nix-index/files"
       fi
       "${pkgs.nix-index}/bin/nix-locate" "$@"
    }
    nix-find() { nix-locate --no-group --top-level -r "$@"; }
    command_not_found_handler() {(
      echo -n '...\b\b\b'
      if [[ "$NIX_MISSING" = auto || "$NIX_MISSING" = always ]]; then
      	MATCH="$(${pkgs.lib.getExe pkgs.fd} "$1" /nix/store --glob --exact-depth 3 --type x --max-results 1)"
        [ -n "$MATCH" ] && PATH="$(dirname "$MATCH"):$PATH" exec "$@"
      fi
      IFS=$'\n' MATCHES=($(nix-locate --no-group --type x --type s --top-level --whole-name --at-root "/bin/$1"))
      if [ "$NIX_MISSING" = never ]; then
        FMT "%1%34❭❭ %0%1$1%0 not found! You can use %1nix-find -wtx /$1%0 to find it\n" >&2
        exit 127
      fi
      case ''${#MATCHES} in
        0) FMT "%1%34❭❭ %0%1$1%0 not found! Are you sure you've typed the command correctly?\n" >&2;;
        1) [[ "$NIX_MISSING" = auto || "$NIX_MISSING" = always ]] &&
              exec nix-shell "''${MATCHES[1]%% *}" --command "$@"
          FMT "%1%34❭❭ %0%1$1%0 not found! Would you like to bring %1''${''${MATCHES[1]%% *}%.*}%0 into scope? " >&2; read
          exec nix-shell "''${MATCHES[1]%% *}" --command "$@" ;;
        *) [ "$NIX_MISSING" = always ] &&
            exec nix-shell "''${MATCHES[1]%% *}" --command "$@"
          FMT "%1%34❭❭ %0%1$1%0 not found! Would you like to bring one of the following packages into scope?\n" >&2
          PS3=""; select PKG in ''${''${MATCHES[@]%% *}%.*}; do
            echo -n '\e[F'; exec nix-shell "$PKG" --command "$@"
          done ;;
      esac
      exit 127
    )}
  '';
}
