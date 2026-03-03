{
  self,
  pkgs,
  tree,
  ...
} @ args: new: old: let
  inherit (builtins) mapAttrs;
  inherit (pkgs) callPackage;
in {
  shanetrs = mapAttrs (k: v: callPackage (v.default or v) args) tree.overlays.shanetrs;
  inherit (self.inputs.nixgl.overlays.default new old) nixgl;
}
