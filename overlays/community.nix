{
  pkgs,
  functions,
  tree,
  ...
} @ args: new: old: let
  inherit (builtins) mapAttrs;
  inherit (functions) importItem;
in {
  shanetrs = mapAttrs (k: v:
    pkgs.callPackage (importItem v) args)
  tree.overlays.shanetrs;
}
