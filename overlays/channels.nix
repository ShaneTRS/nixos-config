{
  self ? null,
  pkgs ? null,
  pkgsConfig ? pkgs.config,
  master ? self.inputs.nixpkgs-master,
  pin ? self.inputs.nixpkgs-pin,
  ...
}: final: prev: {
  pin = import pin {config = pkgsConfig;};
  master = import master {config = pkgsConfig;};
}
