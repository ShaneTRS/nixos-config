{
  description = "My 3rd generation system configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs";
    nixpkgs-pin.url = "github:nixos/nixpkgs/nixos-unstable";
    secrets.url = "git+https://github.com/shanetrs/nixos-secrets";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    inherit (builtins) foldl' isFunction;
    inherit (tundra) getOverlays mkDrvChecks mkTree getSystems;
    inherit (nixpkgs.lib) collect;

    inherit ((import ./overlays/lib.nix specialArgs {} {}).lib) tundra;

    tree = mkTree self;
    specialArgs = {inherit self pkgs lib tree;};
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [self.overlays.default];
      config = {
        allowUnfree = true;
        permittedInsecurePackages = [];
        inherit system;
      };
    };
    inherit (pkgs) lib;
  in {
    apps.${system} = tree.apps specialArgs;
    checks.${system} = mkDrvChecks self {
      lib-tundra = {
        single = true;
        value = self.lib.tundra;
      };
    };
    devShells.${system} = tree.shells specialArgs;
    formatter.${system} = pkgs.alejandra;

    legacyPackages.${system} = pkgs;
    inherit lib;
    overlays.default = final: prev:
      foldl' (acc: this: acc // (this final acc))
      prev (getOverlays specialArgs);
    packages.${system} = pkgs.shanetrs;

    nixosConfigurations = getSystems tree.systems;
    nixosModules.default.imports = collect isFunction tree.modules;
  };
}
