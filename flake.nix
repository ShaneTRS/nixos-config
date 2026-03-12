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
    inherit (builtins) foldl' isFunction;
    inherit (tundra) collectModules getOverlays mkTree nixosConfigurations homeConfigurations;
    inherit (lib) collect;

    tundra = (import ./overlays/lib.nix specialArgs {} {}).lib.tundra;

    tree = mkTree self;
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

    specialArgs = {inherit self pkgs lib tree;};
    getModules = collectModules (collect isFunction tree.modules);
    combinedModules =
      map (x: args: {options = x args;}) (getModules "options")
      ++ getModules "config";
  in {
    apps.${system} = tree.apps specialArgs;
    devShells.${system} = tree.shells specialArgs;
    formatter.${system} = pkgs.alejandra;

    inherit lib;
    overlays.default = final: prev:
      foldl' (acc: this: acc // (this final acc))
      prev (getOverlays specialArgs);
    legacyPackages.${system} = pkgs;
    packages.${system} = pkgs.shanetrs;

    nixosModules.default.imports = getModules "nixos" ++ combinedModules;
    homeModules.default.imports = getModules "home" ++ combinedModules;

    nixosConfigurations = nixosConfigurations tree.systems;
    homeConfigurations = homeConfigurations {
      "shane".id = "persephone";
      "mo".id = "crumb";
      "vm".id = "solis";
    };
  };
}
