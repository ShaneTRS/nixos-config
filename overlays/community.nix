{
  pkgs ? null,
  tree ? null,
  callPackage ? pkgs.callPackage,
  shanetrs ? tree.overlays.shanetrs,
  ...
} @ args: final: prev: let
  inherit (builtins) mapAttrs;
in {
  shanetrs = mapAttrs (_: v: callPackage (v.default or v) args) shanetrs;
}
