{
  description = "My 2nd generation system configuration";

  inputs = {
    self.submodules = true;
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-pin.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixgl = {
      url = "github:nix-community/nixgl";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    inherit (builtins) attrNames foldl' listToAttrs mapAttrs;
    inherit (tundra) getCombinedModules getOverlays mkTree tundraSystem getMachines tundraHome;

    tundra = (import ./overlays/lib.nix specialArgs {} {}).lib.tundra;

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

    combinedTreeModules = getCombinedModules tree.modules;
  in {
    apps.${system} = tree.apps specialArgs;
    checks.${system} = listToAttrs (map (x: {
      name = "homeConfigurations-${x}";
      value = self.homeConfigurations.${x}.activationPackage;
    }) (attrNames self.homeConfigurations));
    devShells.${system} = tree.shells specialArgs;
    formatter.${system} = pkgs.alejandra;

    inherit lib;
    overlays.default = final: prev:
      foldl' (acc: this: acc // (this final acc))
      prev (getOverlays specialArgs);
    legacyPackages.${system} = pkgs;
    packages.${system} = pkgs.shanetrs;

    nixosModules.default.imports = combinedTreeModules "nixos";
    homeModules.default.imports = combinedTreeModules "home";

    nixosConfigurations = mapAttrs tundraSystem (getMachines tree.systems);
    homeConfigurations = mapAttrs tundraHome {
      "shane".id = "persephone";
      "mo".id = "crumb";
      "vm".id = "solis";
    };
  };
}
