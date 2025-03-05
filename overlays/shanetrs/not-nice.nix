{pkgs, ...}:
with pkgs;
  writeShellApplication {
    name = "not-nice";
    runtimeInputs = [util-linux];
    text = ''
      chrt -pf 99 $$
      ''${SUDO:-doas} ionice -c1 -n0 -p$$
      renice -n -20 -p $$
      exec "$@"
    '';
  }
