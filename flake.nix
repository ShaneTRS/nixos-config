# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  description = "My system configuration";

  inputs = {
    pkgs-stable.url = "nixpkgs/nixos-23.11";
    pkgs-unstable.url = "nixpkgs/nixos-unstable";
    pkgs-pinned.url = "nixpkgs/79baff8812a0d68e24a836df0a364c678089e2c7"; # March 1st, 2024

    hm-stable = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "pkgs-stable";
    };
    hm-unstable = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "pkgs-unstable";
    };
    hm-pinned = {
      url = "github:nix-community/home-manager/652fda4ca6dafeb090943422c34ae9145787af37"; # March 1st, 2024
      inputs.nixpkgs.follows = "pkgs-pinned";
    };
  };

  outputs = { self, ... }@inputs:
    let
      base = "stable"; # Controls default package source, and the available options
      settings = {
        graphics = "intel"; # Graphics driver
        hostname = "lachesis"; # The hostname (and profile) for the device
        user = "shane"; # The home and configs to import
      };
      config.allowUnfree = true; # Needed for proprietary software
      system = "x86_64-linux";
      functions = {
        findFirst = pred: list:
          if builtins.length list == 0 then
            throw "findFirst: list is empty"
          else
            let first = builtins.elemAt list 0;
            in if pred first then first else functions.findFirst pred (builtins.tail list);
        configs = file:
          let
            attempt = builtins.tryEval (functions.findFirst builtins.pathExists [
              "${self}/secrets/config/${file}"
              "${self}/configs/${settings.user}/${file}"
              "${self}/configs/shared/${file}"
            ]);
          in if attempt.success then attempt.value else throw "configs: '${file}' not found";
        secrets = "${self}/secrets"; # Returns the secrets directory
        flake = builtins.toString self; # Returns the base directory of the flake
        importRepo = repo: import repo { inherit system config; };
      };
      pkgs-base = functions.importRepo inputs."pkgs-${base}";
    in {
      devShells.${system}.default =
        pkgs-base.mkShell { shellHook = ''exec nix repl --expr "builtins.getFlake \"$PWD?submodules=1\""''; };
      formatter.${system} = pkgs-base.nixfmt;
      packages.${system}.default = with pkgs-base;
        buildEnv {
          name = "flake-shell";
          paths = [ git nil nixfmt nix-output-monitor nixVersions.nix_2_19 ];
        };
      legacyPackages.${system} = self.nixosConfigurations.system.pkgs;
      nixosConfigurations.system = let inherit (inputs."pkgs-${base}") lib;
      in lib.nixosSystem {
        modules = [
          {
            home-manager = {
              extraSpecialArgs = { inherit functions settings; };
              useGlobalPkgs = true;
              useUserPackages = true;
            };
            nixpkgs = with functions; {
              hostPlatform = system;
              inherit config;
              overlays = with inputs;
                [
                  (final: prev: {
                    stable = if base == "stable" then prev else importRepo pkgs-stable;
                    unstable = if base == "unstable" then prev else importRepo pkgs-unstable;
                    pinned = if base == "pinned" then prev else importRepo pkgs-pinned;
                    local = builtins.listToAttrs (map (file: {
                      name = builtins.replaceStrings [ ".nix" ] [ "" ] file;
                      value = pkgs-base.callPackage "${./packages}/${file}" {
                        pkgs = pkgs-base;
                        inherit functions settings;
                      };
                    }) (builtins.attrNames (builtins.readDir ./packages)));
                  })
                ];
            };
            environment.etc."nix/inputs/pkgs".source = inputs."pkgs-${base}";
            nix = {
              registry.pkgs.flake = self;
              settings = {
                auto-optimise-store = true;
                experimental-features = [ "nix-command" "flakes" ];
                nix-path = "nixpkgs=/etc/nix/inputs/pkgs"; # nix-shell uses nixpkgs
                substituters = [ "file:///var/cache/nix" ];
                trusted-users = [ settings.user ];
              };
            };
          }
          inputs."hm-${base}".nixosModules.home-manager
          (lib.mkAliasOptionModule [ "user" ] [ "home-manager" "users" settings.user ])
          (./profiles + "/${settings.profile or settings.hostname}.nix")
          ./hardware.nix
          ./modules
        ];
        specialArgs = { inherit functions settings; };
      };
    };
}
