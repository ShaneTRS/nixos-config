{ pkgs, ... }:
with pkgs;
writeShellScriptBin "not-nice" ''
  export PATH="$PATH:/run/current-system/sw/bin/"
  chrt -pf 99 $$
  doas ionice -c1 -n0 -p$$
  renice -n -20 -p $$
  exec "$@"
''
