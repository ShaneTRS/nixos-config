{
  self,
  functions,
  ...
}: new: old:
with self.inputs; let
  inherit (functions) importRepo;
in {
  stable = importRepo nixpkgs;
  pinned = importRepo pkgs-pinned;
  unstable = importRepo pkgs-unstable;
}
