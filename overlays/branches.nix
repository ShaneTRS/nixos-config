{
  self,
  pkgs,
  ...
}: new: old:
with self.inputs; {
  stable = import nixpkgs pkgs.config;
  pinned = import pkgs-pinned pkgs.config;
  unstable = import pkgs-unstable pkgs.config;
}
