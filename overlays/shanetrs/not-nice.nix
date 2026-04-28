{
  writeShellApplication,
  util-linux,
  ...
}:
writeShellApplication {
  name = "not-nice";
  runtimeInputs = [util-linux];
  text = ''
    chrt -pf 99 $$
    renice -n -20 -p $$
    exec "$@"
  '';
}
