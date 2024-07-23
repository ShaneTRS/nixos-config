{ writeShellScriptBin, ... }:
writeShellScriptBin "nix-shebang" ''
  if [ ! $# -gt 1 ]; then
    echo "Example usage:
    #! /usr/bin/env -S $(basename "$0") shell nixpkgs#python3 --command python
    print('hello world')" >&2
    exit 2
  fi
  cd "$(dirname "''${*: -1}")" || exit
  exec /usr/bin/env -S nix "$@"
''
