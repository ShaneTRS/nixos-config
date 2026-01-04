{
  self,
  pkgsConfig,
  ...
}: new: old:
with self.inputs; {
  stable = import nixpkgs pkgsConfig;
  pinned = import pkgs-pinned pkgsConfig;
  unstable = import pkgs-unstable pkgsConfig;
}
