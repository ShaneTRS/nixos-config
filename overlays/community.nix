{
  pkgs,
  fn,
  tree,
  ...
} @ args: new: old: let
  inherit (builtins) mapAttrs;
  inherit (fn) importItem;
in {
  shanetrs = mapAttrs (k: v:
    pkgs.callPackage (importItem v) args)
  tree.overlays.shanetrs;
  # inherit (self.inputs.nixgl.overlays.default new old) nixgl;
}
