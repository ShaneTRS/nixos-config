# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  description = "My system configuration";

  inputs = {
    pkgs-stable.url = "nixpkgs/nixos-23.11";
    pkgs-unstable.url = "nixpkgs/nixos-unstable";
    pkgs-pinned.url = "nixpkgs/79baff8812a0d68e24a836df0a364c678089e2c7"; # March 1st, 2024

    # This cannot be simplified because flake.nix is *not* a real nix file. Only `self.outputs` is.
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
      machine = let this = builtins.fromTOML (builtins.readFile ./machine.toml);
      in this // { profile = this.profile or this.hostname; };
      inherit (machine) base serial system;
      config.allowUnfree = true; # Needed for proprietary software
      functions = let flake = self.outPath;
      in rec {
        findFirst = pred: list:
          if builtins.length list == 0 then
            throw "findFirst: list is empty"
          else # Find first item to match predicate
            let first = builtins.elemAt list 0; in if pred first then first else findFirst pred (builtins.tail list);
        configs = file:
          let # Import a config, with most personal taking precedence
            attempt = builtins.tryEval (findFirst builtins.pathExists [
              "${flake}/secrets/config/${machine.profile}/${file}"
              "${flake}/secrets/config/all/${file}"
              "${flake}/configs/${machine.user}/${machine.profile}/${file}"
              "${flake}/configs/${machine.user}/all/${file}"
              "${flake}/configs/global/${machine.profile}/${file}"
              "${flake}/configs/global/all/${file}"
            ]);
          in if attempt.success then attempt.value else throw "configs: '${file}' not found";
        inherit flake; # Returns the base directory of the flake
        secrets = "${flake}/secrets"; # Returns the secrets directory
        importRepo = repo: import repo { inherit system config; }; # Pass system and config to repo
      };
      pkgs-base = functions.importRepo inputs."pkgs-${base}";
    in {
      devShells.${system}.default =
        pkgs-base.mkShell { shellHook = ''exec nix repl --expr "builtins.getFlake \"$PWD?submodules=1\""''; };
      formatter.${system} = pkgs-base.nixfmt;
      packages.${system}.default = with pkgs-base;
        buildEnv {
          name = "flake-shell";
          paths = [ bash coreutils gawk gnused git nil nixfmt nix-output-monitor nixVersions.nix_2_19 sudo ugrep ];
        };
      legacyPackages.${system} = self.nixosConfigurations.default.pkgs;
      nixosConfigurations.default = let inherit (inputs."pkgs-${base}") lib;
      in lib.nixosSystem {
        modules = [
          {
            home-manager = {
              extraSpecialArgs = { inherit functions machine; };
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
                        inherit functions machine;
                      };
                    }) (builtins.attrNames (builtins.readDir ./packages)));
                  })
                ];
            };
            environment.etc."nix/inputs/pkgs".source = inputs."pkgs-${base}";
            nix = {
              package = pkgs-base.nixVersions.nix_2_19;
              registry.pkgs.flake = self;
              settings = {
                auto-optimise-store = true;
                experimental-features = [ "nix-command" "flakes" ];
                nix-path = "nixpkgs=/etc/nix/inputs/pkgs"; # nix-shell uses nixpkgs
                substituters = [ "file:///var/cache/nix" ];
                trusted-users = [ machine.user ];
                use-xdg-base-directories = true;
              };
            };
          }
          inputs."hm-${base}".nixosModules.home-manager
          (lib.mkAliasOptionModule [ "user" ] [ "home-manager" "users" machine.user ])
          (./profiles + "/${machine.profile or machine.hostname}.nix")
          (if serial == "" then { } else "${./hardware}/${serial}.nix")
          ./modules
        ];
        specialArgs = { inherit functions machine; };
      };
    };
}
