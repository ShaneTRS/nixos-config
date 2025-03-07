{
  self,
  fn,
  ...
}: new: old:
with self.inputs; let
  inherit (fn) importRepo;
in {
  stable = importRepo nixpkgs;
  pinned = importRepo pkgs-pinned;
  unstable = importRepo pkgs-unstable;
}
