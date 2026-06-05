{
  self ? null,
  pkgs ? null,
  importArgs ? {
    inherit (pkgs) config;
    inherit (pkgs.stdenv.hostPlatform) system;
  },
  master ? self.inputs.nixpkgs-master,
  pin ? self.inputs.nixpkgs-pin,
  ...
}: final: prev: {
  pin = import pin importArgs;
  master = import master importArgs;
}
