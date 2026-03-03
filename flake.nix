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
    home-manager,
    ...
  }: let
    inherit (builtins) isFunction;
    inherit (lib) collect mkTree collectModules tundra;
    inherit (tundra specialArgs) nixosConfigurations homeConfigurations applyOverlays;

    system = "x86_64-linux";
    pkgs =
      applyOverlays (import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [];
          inherit system;
        };
      })
      specialArgs;
    lib = nixpkgs.lib.extend (old: new: home-manager.lib // import ./lib.nix);
    tree = mkTree self;

    specialArgs = {inherit self pkgs lib tree;};
    getModules = collectModules (collect isFunction tree.modules);
    combinedModules =
      map (x: args: {options = x args;}) (getModules "options")
      ++ getModules "config";
  in {
    apps.${system} = tree.apps specialArgs;
    devShells.${system} = tree.shells specialArgs;
    formatter.${system} = pkgs.alejandra;

    legacyPackages.${system} = pkgs;
    inherit lib;

    nixosModules.default.imports = getModules "nixos" ++ combinedModules;
    homeModules.default.imports = getModules "home" ++ combinedModules;

    nixosConfigurations = nixosConfigurations {
      "230925799001945" = {
        hostname = "persephone";
        user = "shane";
      };
      "H1XH7F3CNCMC0015F0243" = {
        hostname = "lachesis";
        user = "shane";
      };
      "MXL0265298" = {
        hostname = "dionysus";
        user = "shane";
      };
      "MOELITEBOOK" = {
        hostname = "mo-elitebook";
        user = "mo";
      };
      "0" = {
        hostname = "vm";
        profile = "bolillo";
        user = "vm";
      };
    };
    homeConfigurations = homeConfigurations {
      "shane".profile = "persephone";
      "mo".profile = "crumb";
      "vm".profile = "solis";
    };
  };
}
