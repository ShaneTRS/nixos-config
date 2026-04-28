{
  nixosConfig ? null,
  symlinkJoin,
  writeShellScriptBin,
  nixVersions,
  nixArgs ? "--extra-experimental-features 'flakes nix-command'",
  nixPackage ? nixosConfig.nix.package or nixVersions.latest,
  ...
}:
symlinkJoin {
  name = "nix-wrapped";
  inherit (nixPackage) meta pname version;
  paths = [
    (writeShellScriptBin "nix" ''
      if ! [[ " $* " =~ ' develop ' ]] || [[ " $* "  =~ ' -c ' ]] || [[ " $* " =~ ' --command ' ]]; then
        exec -a "$0" ${nixPackage}/bin/nix ${nixArgs} "$@"
      fi
      args=() develop=false shell=false
      for i in "$@"; do
        if ! "$develop"; then
          args+=("$i")
          [ "$i" = develop ] && develop=true
          continue
        fi
        if ! "$shell" && [[ $i != -* ]]; then
          args+=("$i" "-c" "$SHELL")
          shell=true
          continue
        fi
        args+=("$i")
      done
      exec -a "$0" ${nixPackage}/bin/nix ${nixArgs} "''${args[@]}"
    '')
    nixPackage
  ];
}
