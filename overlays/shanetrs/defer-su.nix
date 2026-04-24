{
  symlinkJoin,
  writeShellApplication,
  coreutils,
  openssl,
  ...
}:
symlinkJoin {
  name = "defer-su";
  meta.mainProgram = "defer-su";
  paths = [
    (writeShellApplication {
      name = "defer-su.init";
      runtimeInputs = [coreutils openssl];
      text = ''
        [ "$(id -u)" -eq 0 ] || exit 20
        DSU_KEYFILES="/tmp/defer-su/$(openssl rand -hex 16)"
        # shellcheck disable=SC2174
        mkdir -pm 600 "$DSU_KEYFILES"
        PATH="''${DSU_PATH:-}:$PATH"
        for i in "$@"; do
          ln -sfT "$(readlink -f "$(type -P "$i")")" \
            "$DSU_KEYFILES/$(base64 -w0 <<< "$i").$(openssl rand -hex 6)"
        done
        printf "%s=%s\n" DSU_KEYFILES "$DSU_KEYFILES"
      '';
    })
    (writeShellApplication {
      name = "defer-su";
      runtimeInputs = [coreutils];
      text = ''
        [ "$(id -u)" -eq 0 ] || exit 20
        [ "$(stat -c '%u %g %a %F' "''${DSU_KEYFILES:-}" 2>/dev/null)" = '0 0 600 directory' ] || exit 21
        matches=("$DSU_KEYFILES/$(base64 -w0 <<< "$1")."*) first="''${matches[0]}"
        exe="$(readlink -e "$first" 2>/dev/null || exit 22)"
        rm "$first" || exit 23
        rmdir "$DSU_KEYFILES" --ignore-fail-on-non-empty
        exec -a "$1" "$exe" "''${@:2}"
      '';
    })
  ];
}
