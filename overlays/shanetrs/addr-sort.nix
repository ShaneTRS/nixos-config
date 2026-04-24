{
  writeShellScriptBin,
  coreutils,
  inetutils,
  ...
}:
writeShellScriptBin "addr-sort" ''
  { for i in "$@"; do if ${inetutils}/bin/ping "$i" -c1 -W1 &>/dev/null; then
      printf "%s\n" "$i"
    fi & done
    wait -n
  } | ${coreutils}/bin/head -n1
''
