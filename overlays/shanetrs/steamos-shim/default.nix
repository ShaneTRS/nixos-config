{symlinkJoin, ...}:
symlinkJoin {
  name = "steamos-shim";
  paths = [./src];
}
