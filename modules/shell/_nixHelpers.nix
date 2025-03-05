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
      IN_NIX_SHELL=1 NIXPKGS_ALLOW_UNFREE=1 nix shell --impure "''${ARGS[@]}"
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

  nixIndex = {pkgs, ...}: ''
    nix-find() { ${pkgs.nix-index}/bin/nix-locate --no-group --top-level -r "$@"; }
    command_not_found_handler() {(
      CMD="$1" IFS=$'\n'
      SGR() { echo -ne "\e[''${(j:m\e[:)@}m"; }
      if [ "$NIX_MISSING" = "never" ]; then
        echo "$(SGR 1 34)❭❭ $(SGR 0 1)$CMD$(SGR 0) not found! You can use $(SGR 1)nix-find -wtx /$CMD$(SGR 0) to find it" >&2
        exit 127
      fi
      PACKAGES=($(${pkgs.nix-index}/bin/nix-locate --minimal --no-group --type x --type s --top-level --whole-name --at-root "/bin/$CMD"))
      case "''${#PACKAGES}" in
        0) echo "$(SGR 1 34)❭❭ $(SGR 0 1)$CMD$(SGR 0) not found! Are you sure you've typed the command correctly?" >&2 ;;
        1) [ "$NIX_MISSING" = "auto" ] &&
            exec nix-shell "''${PACKAGES[1]}" --command "$@";
          echo -n "$(SGR 1 34)❭❭ $(SGR 0 1)$CMD$(SGR 0) not found! Would you like to bring $(SGR 1)''${PACKAGES[1]%.*}$(SGR 0) into scope? " >&2; read
          exec nix-shell "''${PACKAGES[1]}" --command "$@" ;;
        *) [ "$NIX_MISSING" = "always" ] &&
            exec nix-shell "''${PACKAGES[1]}" --command "$@";
          echo "$(SGR 1 34)❭❭ $(SGR 0 1)$CMD$(SGR 0) not found! Would you like to bring one of the following packages into scope?" >&2
          PS3=""; select PKG in ''${PACKAGES[@]%.*}; do exec nix-shell "$PKG" --command "$@"; done ;;
      esac
      exit 127
    )}
  '';
}
