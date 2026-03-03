{
  self,
  pkgs,
  ...
}: new: old:
with self.inputs; {
  pin = import nixpkgs-pin pkgs.config;
  master = import nixpkgs-master pkgs.config;
}
