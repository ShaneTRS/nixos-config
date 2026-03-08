{
  self ? null,
  pkgs ? null,
  tree ? null,
  callPackage ? pkgs.callPackage,
  nixgl ? self.inputs.nixgl.overlays.default,
  shanetrs ? tree.overlays.shanetrs,
  ...
} @ args: final: prev: let
  inherit (builtins) mapAttrs;
in {
  shanetrs = mapAttrs (k: v: callPackage (v.default or v) args) shanetrs;
  inherit (nixgl final prev) nixgl;
}
